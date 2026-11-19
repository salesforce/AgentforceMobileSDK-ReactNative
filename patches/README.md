# React Native 0.77 patches

`react-native+0.77.3.patch` is applied by `patch-package` during npm setup.
It preserves the existing Hermes download validation and uses Homebrew Boost
headers while retaining React Native 0.77's Boost privacy resource.

The Boost podspec creates its Homebrew header link during `prepare_command`,
before CocoaPods indexes source files. The Podfile's `post_install` hook must
preserve that tree so CocoaPods can still lock its cached header and privacy
resource paths afterward. Replacing it with another Boost version can remove
headers such as `bind/bind_cc.hpp` and cause `pod install` to fail.

Existing Pods directories produced by the old flattening hook are repaired during
`pre_install`: CocoaPods restores the pinned Boost source and privacy resource
before generating header maps. This fixes missing Boost includes on incremental
developer builds without changing Homebrew headers or discarding other pods.

Run the offline regression check with CocoaPods installed:

```bash
ruby scripts/tests/boost_post_install_test.rb
```

React Native 0.77 pins fmt 11.0.2. The shared Podfile pre-install hook adjusts
that version's compiler detection for Apple Clang 21+, avoiding its `consteval`
compilation errors while retaining C++20. The adjustment applies to the fmt
header so dependent pods see the same configuration; fmt 11.0.2 overwrites
command-line `FMT_USE_CONSTEVAL` definitions. Other fmt versions are untouched.
Remove the adjustment when upgrading to a compatible fmt release.

```bash
ruby scripts/tests/fmt_compatibility_test.rb
```

The npm postinstall step and `installandroid.js` align the React Native Gradle
plugin's AGP and Kotlin versions with this app. React Native 0.77 already uses the
`compilerOptions` DSL and no longer needs the older Gradle source patches.

When changing React Native versions, regenerate the versioned patch from a clean
package installation and rerun the Android and iOS setup flows.
