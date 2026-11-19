#!/usr/bin/env python3
"""Check the native libraries in local Android release APKs or AABs.

Usage: python3 scripts/check-android-native-alignment.py app-release.apk [app.aab ...]

Only 64-bit ABIs determine the exit status. Android's 16 KB page-size
requirement applies to 64-bit devices; 32-bit results are informational.
"""

import argparse
import collections
import struct
import sys
import zipfile
from pathlib import Path


PAGE_SIZE = 0x4000
REQUIRED_ABIS = frozenset(("arm64-v8a", "x86_64"))


def native_library_parts(path):
    parts = path.split("/")
    if len(parts) < 3 or not path.endswith(".so"):
        return None
    if parts[0] == "lib":  # APK
        return parts[1], parts[-1]
    if len(parts) >= 4 and parts[1] == "lib":  # AAB module
        return parts[2], parts[-1]
    return None


def load_alignment(data):
    if data[:4] != b"\x7fELF" or data[4] not in (1, 2) or data[5] not in (1, 2):
        raise ValueError("invalid ELF header")
    is_64_bit = data[4] == 2
    endian = "<" if data[5] == 1 else ">"
    header_offset = 32 if is_64_bit else 28
    table_offset = struct.unpack_from(endian + ("Q" if is_64_bit else "I"), data, header_offset)[0]
    entry_size, entry_count = struct.unpack_from(endian + "HH", data, 54 if is_64_bit else 42)
    if entry_size < (56 if is_64_bit else 32) or table_offset + entry_size * entry_count > len(data):
        raise ValueError("invalid ELF program header table")
    alignments = []
    for index in range(entry_count):
        offset = table_offset + index * entry_size
        if struct.unpack_from(endian + "I", data, offset)[0] == 1:  # PT_LOAD
            alignments.append(
                struct.unpack_from(endian + ("Q" if is_64_bit else "I"), data, offset + (48 if is_64_bit else 28))[0]
            )
    if not alignments:
        raise ValueError("ELF has no PT_LOAD segments")
    return min(alignments)


def zip_data_offset(apk, entry):
    apk.seek(entry.header_offset)
    header = apk.read(30)
    if len(header) != 30 or header[:4] != b"PK\x03\x04":
        raise ValueError("invalid ZIP local file header")
    name_size, extra_size = struct.unpack_from("<HH", header, 26)
    return entry.header_offset + 30 + name_size + extra_size


def inspect(path):
    is_apk = path.suffix.lower() == ".apk"
    counts = collections.Counter()
    errors = []
    with zipfile.ZipFile(path) as archive, path.open("rb") as raw:
        for entry in archive.infolist():
            parts = native_library_parts(entry.filename)
            if parts is None:
                continue
            abi, name = parts
            if abi not in REQUIRED_ABIS and abi not in ("armeabi-v7a", "x86"):
                continue
            counts[(abi, "total")] += 1
            try:
                alignment = load_alignment(archive.read(entry))
                if alignment < PAGE_SIZE:
                    counts[(abi, "elf_bad")] += 1
                    if abi in REQUIRED_ABIS:
                        errors.append(f"{entry.filename}: PT_LOAD alignment {alignment:#x}")
                if is_apk and entry.compress_type == zipfile.ZIP_STORED:
                    if zip_data_offset(raw, entry) % PAGE_SIZE:
                        counts[(abi, "zip_bad")] += 1
                        if abi in REQUIRED_ABIS:
                            errors.append(f"{entry.filename}: uncompressed APK entry is not 16 KB ZIP aligned")
            except (ValueError, struct.error, zipfile.BadZipFile) as exc:
                errors.append(f"{entry.filename}: {exc}")
    if not any(counts[(abi, "total")] for abi in REQUIRED_ABIS):
        errors.append("no 64-bit native libraries found")
    print(path)
    for abi in ("arm64-v8a", "x86_64", "armeabi-v7a", "x86"):
        if counts[(abi, "total")]:
            scope = "required" if abi in REQUIRED_ABIS else "informational"
            print(
                f"  {abi}: {counts[(abi, 'total')]} libraries, "
                f"{counts[(abi, 'elf_bad')]} ELF below 16 KB, "
                f"{counts[(abi, 'zip_bad')]} uncompressed ZIP entries misaligned ({scope})"
            )
    for error in errors:
        print(f"  FAIL {error}")
    if not is_apk:
        print("  AAB ZIP offsets are not final APK offsets; also check bundletool's PAGE_ALIGNMENT_16K setting.")
    return bool(errors)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifacts", nargs="+", type=Path, help="release APK or AAB files")
    args = parser.parse_args()
    failed = False
    for path in args.artifacts:
        if path.suffix.lower() not in (".apk", ".aab"):
            parser.error(f"expected .apk or .aab: {path}")
        try:
            failed = inspect(path) or failed
        except (OSError, zipfile.BadZipFile) as exc:
            print(f"{path}: {exc}", file=sys.stderr)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
