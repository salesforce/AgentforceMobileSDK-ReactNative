#!/usr/bin/env node

var packageJson = require('./package.json');
var execSync = require('child_process').execSync;
var path = require('path');
var fs = require('fs');
var rimraf = require('rimraf');

console.log('📦 Installing npm dependencies...');
try {
  execSync('npm install --legacy-peer-deps --ignore-scripts', { stdio: [0, 1, 2] });
} catch (e) {
  console.error('❌ npm install failed. Try: npm install --legacy-peer-deps --ignore-scripts');
  process.exit(1);
}

// Apply patches to fix react-native-gradle-plugin warnings and Kotlin version
console.log('🔧 Applying patches to react-native-gradle-plugin...');

// Patch 0: Update Kotlin and AGP versions in gradle plugin to match project
var libsVersionsPath = 'node_modules/@react-native/gradle-plugin/gradle/libs.versions.toml';
applyPatch(
  'libs.versions.toml (Kotlin)',
  libsVersionsPath,
  'kotlin = "1.9.22"',
  'kotlin = "2.2.0"'
);
applyPatch(
  'libs.versions.toml (AGP)',
  libsVersionsPath,
  'agp = "8.2.1"',
  'agp = "8.9.1"'
);

// Patch 0.5: Migrate build.gradle.kts to Kotlin 2.2.0 compilerOptions DSL
var buildGradleKtsPath = 'node_modules/@react-native/gradle-plugin/react-native-gradle-plugin/build.gradle.kts';
if (fs.existsSync(path.join(__dirname, buildGradleKtsPath))) {
  var buildGradleKtsContent = fs.readFileSync(path.join(__dirname, buildGradleKtsPath), 'utf8');
  var oldKotlinOptions = 'tasks.withType<KotlinCompile>().configureEach {\n  kotlinOptions {\n    apiVersion = "1.6"\n    // See comment above on JDK 11 support\n    jvmTarget = "11"\n    allWarningsAsErrors = true\n  }\n}';
  var newCompilerOptions = 'tasks.withType<KotlinCompile>().configureEach {\n  compilerOptions {\n    apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)\n    // See comment above on JDK 11 support\n    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)\n    // Disabled to prevent build failures from deprecation warnings in Kotlin 2.2.0\n    allWarningsAsErrors.set(false)\n  }\n}';

  if (buildGradleKtsContent.indexOf(newCompilerOptions) !== -1) {
    console.log('   ⏭️  Patch already applied: build.gradle.kts (compilerOptions)');
  } else if (buildGradleKtsContent.indexOf(oldKotlinOptions) !== -1) {
    buildGradleKtsContent = buildGradleKtsContent.replace(oldKotlinOptions, newCompilerOptions);
    fs.writeFileSync(path.join(__dirname, buildGradleKtsPath), buildGradleKtsContent, 'utf8');
    console.log('   ✅ Applied patch: build.gradle.kts (compilerOptions)');
  } else {
    console.warn('⚠️  Patch target not found (file may have changed): build.gradle.kts');
  }
}

// Patch 0.6: Migrate settings-plugin/build.gradle.kts to Kotlin 2.2.0 compilerOptions DSL
var settingsPluginGradlePath = 'node_modules/@react-native/gradle-plugin/settings-plugin/build.gradle.kts';
if (fs.existsSync(path.join(__dirname, settingsPluginGradlePath))) {
  var settingsPluginContent = fs.readFileSync(path.join(__dirname, settingsPluginGradlePath), 'utf8');

  if (settingsPluginContent.indexOf(newCompilerOptions) !== -1) {
    console.log('   ⏭️  Patch already applied: settings-plugin/build.gradle.kts (compilerOptions)');
  } else if (settingsPluginContent.indexOf(oldKotlinOptions) !== -1) {
    settingsPluginContent = settingsPluginContent.replace(oldKotlinOptions, newCompilerOptions);
    fs.writeFileSync(path.join(__dirname, settingsPluginGradlePath), settingsPluginContent, 'utf8');
    console.log('   ✅ Applied patch: settings-plugin/build.gradle.kts (compilerOptions)');
  } else {
    console.warn('⚠️  Patch target not found (file may have changed): settings-plugin/build.gradle.kts');
  }
}

function applyPatch(patchFile, targetFile, searchStr, replaceStr) {
  var targetPath = path.join(__dirname, targetFile);

  if (!fs.existsSync(targetPath)) {
    console.warn('⚠️  Target file not found: ' + targetFile);
    return;
  }

  var targetContent = fs.readFileSync(targetPath, 'utf8');

  if (targetContent.indexOf(searchStr) !== -1) {
    targetContent = targetContent.replace(searchStr, replaceStr);
    fs.writeFileSync(targetPath, targetContent, 'utf8');
    console.log('   ✅ Applied patch: ' + patchFile);
  } else if (targetContent.indexOf(replaceStr) !== -1) {
    console.log('   ⏭️  Patch already applied: ' + patchFile);
  } else {
    console.warn('⚠️  Patch target not found (file may have changed): ' + patchFile);
  }
}

// Patch 1: Fix unnecessary safe call warning in ReactPlugin.kt
applyPatch(
  'ReactPlugin.kt.patch',
  'node_modules/@react-native/gradle-plugin/react-native-gradle-plugin/src/main/kotlin/com/facebook/react/ReactPlugin.kt',
  '    val jvmVersion = Jvm.current()?.javaVersion?.majorVersion',
  '    val jvmVersion = Jvm.current().javaVersion?.majorVersion'
);

// Patch 2: Suppress deprecation warning in BundleHermesCTask.kt
// Note: Check for exact context to avoid duplicate annotations
var bundleHermesCTaskPath = path.join(__dirname, 'node_modules/@react-native/gradle-plugin/react-native-gradle-plugin/src/main/kotlin/com/facebook/react/tasks/BundleHermesCTask.kt');
if (fs.existsSync(bundleHermesCTaskPath)) {
  var content = fs.readFileSync(bundleHermesCTaskPath, 'utf8');
  var searchPattern = 'File(jsIntermediateSourceMapsDir.get().asFile, "$bundleAssetName.compiler.map")\n\n  private fun runCommand(command: List<Any>) {';
  var replacePattern = 'File(jsIntermediateSourceMapsDir.get().asFile, "$bundleAssetName.compiler.map")\n\n  @Suppress("DEPRECATION")\n  private fun runCommand(command: List<Any>) {';

  if (content.indexOf(replacePattern) !== -1) {
    console.log('   ⏭️  Patch already applied: BundleHermesCTask.kt.patch');
  } else if (content.indexOf(searchPattern) !== -1) {
    content = content.replace(searchPattern, replacePattern);
    fs.writeFileSync(bundleHermesCTaskPath, content, 'utf8');
    console.log('   ✅ Applied patch: BundleHermesCTask.kt.patch');
  } else {
    console.warn('⚠️  Patch target not found (file may have changed): BundleHermesCTask.kt.patch');
  }
}

console.log('\n✅ Android setup complete.');
console.log('   Run: npm run android');
