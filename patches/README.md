# Patches

This directory contains patches for fixing warnings in the react-native-gradle-plugin that are treated as errors when building the Android app.

## Applied Patches

### libs.versions.toml.patch
Fixes Kotlin and AGP version mismatches between the project and react-native-gradle-plugin.

**Changes**:
- Updates Kotlin from 1.9.22 to 2.2.0 to match project requirements
- Updates Android Gradle Plugin (AGP) from 8.2.1 to 8.9.1 to match project configuration

This prevents the error: "Found interface org.jetbrains.kotlin.gradle.dsl.KotlinTopLevelExtension, but class was expected"

### build.gradle.kts.patch
Migrates the react-native-gradle-plugin build script to use Kotlin 2.2.0's new `compilerOptions` DSL.

**Changes**:
- Replaces deprecated `kotlinOptions` with `compilerOptions`
- Migrates `apiVersion`, `jvmTarget`, and `allWarningsAsErrors` to the new DSL syntax
- Disables `allWarningsAsErrors` to prevent build failures from deprecation warnings

This fixes the error: "Using 'kotlinOptions' is an error. Please migrate to the compilerOptions DSL."

### settings-plugin-build.gradle.kts.patch
Migrates the settings-plugin build script to use Kotlin 2.2.0's new `compilerOptions` DSL (same fix as build.gradle.kts.patch but for the settings-plugin).

### ReactPlugin.kt.patch
Fixes the Kotlin warning: "Unnecessary safe call on a non-null receiver of type Jvm!"

**Change**: Removes unnecessary safe call operator on `Jvm.current()` (which is non-null)
- Before: `Jvm.current()?.javaVersion?.majorVersion`
- After: `Jvm.current().javaVersion?.majorVersion`

### BundleHermesCTask.kt.patch
Fixes the Kotlin warning: "'exec(Action<in ExecSpec!>!): ExecResult!' is deprecated"

**Change**: Adds `@Suppress("DEPRECATION")` annotation to the `runCommand` function to suppress the deprecation warning

## How Patches Are Applied

Patches are automatically applied during the Android installation process (`npm run install:android`).

The `installandroid.js` script applies these patches after running `npm install` but before building the SDK dependencies.

## Updating Patches

If you need to update a patch:
1. Edit the `.patch` file in this directory
2. Follow the unified diff format
3. Test by running `npm run install:android` in a clean environment
