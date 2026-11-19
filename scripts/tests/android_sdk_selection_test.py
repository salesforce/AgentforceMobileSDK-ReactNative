"""Exercise SDK selection with real, offline Gradle composite builds."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class AndroidSDKSelectionTest(unittest.TestCase):
    sample = Path(__file__).resolve().parents[2]

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="rn-sdk-selection-")
        self.root = Path(self.temp.name)
        self.android = self.root / "react-native/sdk/android"
        self.android.mkdir(parents=True)
        shutil.copyfile(self.sample / "android/agentforce-sdk-settings.gradle",
                        self.android / "agentforce-sdk-settings.gradle")
        (self.android / "settings.gradle").write_text(
            "rootProject.name = 'sample'\napply from: 'agentforce-sdk-settings.gradle'\n")
        (self.android / "build.gradle").write_text("""
configurations { sdkProbe }
dependencies {
    sdkProbe 'com.salesforce.android.agentforcesdk:agentforce-sdk:1.0'
    sdkProbe 'com.salesforce.android.agentforcesdk:agentforce-sdk-voice:1.0'
}
tasks.register('sdkSource') {
    doLast {
        configurations.sdkProbe.incoming.resolutionResult.allDependencies.each {
            if (it instanceof org.gradle.api.artifacts.result.UnresolvedDependencyResult) {
                throw new GradleException(it.failure.message)
            }
            println "SDK_SELECTION: ${it.selected.id}"
        }
    }
}
""")

    def tearDown(self):
        self.temp.cleanup()

    def local_sdk(self):
        sdk = self.root / "android/sdk"
        sdk.mkdir(parents=True)
        (sdk / "settings.gradle.kts").write_text(
            'rootProject.name = "sdk"\ninclude(":agentforce-sdk", ":agentforce-sdk-voice")\n')
        (sdk / "build.gradle.kts").write_text(
            'subprojects { group = "com.salesforce.android.agentforcesdk"; version = "99.0" }\n')
        for name in ("agentforce-sdk", "agentforce-sdk-voice"):
            module = sdk / name
            module.mkdir()
            (module / "build.gradle.kts").write_text('plugins { `java-library` }\n')

    def gradle(self, directory, task="sdkSource"):
        # Use the sample's wrapper; the probe needs only Gradle's built-in plugins.
        return subprocess.run(
            [str(self.sample / "android/gradlew"), "--offline", "--console=plain",
             "-p", str(directory), task], text=True, capture_output=True)

    def assert_local(self, result):
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        selections = [line for line in result.stdout.splitlines() if line.startswith("SDK_SELECTION:")]
        self.assertEqual(2, len(selections), result.stdout)
        for selection in selections:
            self.assertIn("project :sdk:agentforce-sdk", selection)

    def test_direct_sample_build_selects_local_sdk(self):
        self.local_sdk()
        self.assert_local(self.gradle(self.android))

    def test_outer_composite_can_already_include_the_same_sdk(self):
        self.local_sdk()
        (self.root / "settings.gradle").write_text(
            "includeBuild('android/sdk')\nincludeBuild('react-native/sdk/android')\n")
        self.assert_local(self.gradle(self.root, ":android:sdkSource"))

    def test_standalone_checkout_uses_published_versions(self):
        repository = self.android / "repository"
        for name in ("agentforce-sdk", "agentforce-sdk-voice"):
            artifact = repository / "com/salesforce/android/agentforcesdk" / name / "1.0"
            artifact.mkdir(parents=True)
            (artifact / f"{name}-1.0.pom").write_text(
                '<project><modelVersion>4.0.0</modelVersion>'
                '<groupId>com.salesforce.android.agentforcesdk</groupId>'
                f'<artifactId>{name}</artifactId><version>1.0</version></project>')
        with (self.android / "build.gradle").open("a") as build:
            build.write(f'\nrepositories {{ maven {{ url = uri({json.dumps(str(repository))}) }} }}\n')
        result = self.gradle(self.android)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("using published Maven dependencies", result.stdout)
        self.assertIn("SDK_SELECTION: com.salesforce.android.agentforcesdk:agentforce-sdk:1.0", result.stdout)
        self.assertNotIn("SDK_SELECTION: project", result.stdout)

    def test_incomplete_local_checkout_fails_without_falling_back(self):
        self.local_sdk()
        (self.root / "android/sdk/agentforce-sdk-voice/build.gradle.kts").unlink()
        result = self.gradle(self.android)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("Incomplete local Agentforce SDK", result.stderr)
        self.assertIn("agentforce-sdk-voice/build.gradle.kts", result.stderr)
        self.assertNotIn("using published Maven dependencies", result.stdout)


if __name__ == "__main__":
    unittest.main()
