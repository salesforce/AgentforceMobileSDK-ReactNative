#!/usr/bin/env node

var packageJson = require('./package.json');
var execSync = require('child_process').execSync;
var path = require('path');
var fs = require('fs');
var os = require('os');
var rimraf = require('rimraf');
var interactiveOAuth = require('./scripts/interactive-oauth');
var bootconfig = require('./scripts/update-bootconfig');

// Check for help flag
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log('\n╔═══════════════════════════════════════════════════════════════╗');
  console.log('║     Android Multi-App Installation - AgentforceSDK            ║');
  console.log('╚═══════════════════════════════════════════════════════════════╝\n');
  console.log('Usage:');
  console.log('  node installandroid.js [target]\n');
  console.log('Target:');
  console.log('  service        Install Service Agent only (no Mobile SDK)');
  console.log('  employee       Install Employee Agent only (with Mobile SDK)');
  console.log('  all            Install both apps (default)\n');
  console.log('Examples:');
  console.log('  node installandroid.js service   # Service Agent only');
  console.log('  node installandroid.js employee  # Employee Agent only');
  console.log('  node installandroid.js all       # Both apps');
  console.log('  node installandroid.js           # Same as "all"\n');
  console.log('OAuth Configuration:');
  console.log('  When installing Employee Agent, you will be prompted to configure');
  console.log('  OAuth credentials interactively during installation.\n');
  process.exit(0);
}

// Parse target argument: service, employee, all (default: all)
var target = process.argv[2] || 'all';
if (!['service', 'employee', 'all'].includes(target)) {
  console.error('❌ Invalid target: ' + target);
  console.error('   Usage: node installandroid.js [service|employee|all]');
  console.error('   Examples:');
  console.error('     node installandroid.js service   # Service Agent only (no Mobile SDK)');
  console.error('     node installandroid.js employee  # Employee Agent only (with Mobile SDK)');
  console.error('     node installandroid.js all       # Both apps (with Mobile SDK)');
  console.error('     node installandroid.js           # Same as "all" (backward compatible)');
  process.exit(1);
}

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
  'kotlin = "2.2.0"',
);
applyPatch('libs.versions.toml (AGP)', libsVersionsPath, 'agp = "8.2.1"', 'agp = "8.9.1"');

// Patch 0.5: Migrate build.gradle.kts to Kotlin 2.2.0 compilerOptions DSL
var buildGradleKtsPath =
  'node_modules/@react-native/gradle-plugin/react-native-gradle-plugin/build.gradle.kts';
if (fs.existsSync(path.join(__dirname, buildGradleKtsPath))) {
  var buildGradleKtsContent = fs.readFileSync(path.join(__dirname, buildGradleKtsPath), 'utf8');
  var oldKotlinOptions =
    'tasks.withType<KotlinCompile>().configureEach {\n  kotlinOptions {\n    apiVersion = "1.6"\n    // See comment above on JDK 11 support\n    jvmTarget = "11"\n    allWarningsAsErrors = true\n  }\n}';
  var newCompilerOptions =
    'tasks.withType<KotlinCompile>().configureEach {\n  compilerOptions {\n    apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)\n    // See comment above on JDK 11 support\n    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)\n    // Disabled to prevent build failures from deprecation warnings in Kotlin 2.2.0\n    allWarningsAsErrors.set(false)\n  }\n}';

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
var settingsPluginGradlePath =
  'node_modules/@react-native/gradle-plugin/settings-plugin/build.gradle.kts';
if (fs.existsSync(path.join(__dirname, settingsPluginGradlePath))) {
  var settingsPluginContent = fs.readFileSync(
    path.join(__dirname, settingsPluginGradlePath),
    'utf8',
  );

  if (settingsPluginContent.indexOf(newCompilerOptions) !== -1) {
    console.log('   ⏭️  Patch already applied: settings-plugin/build.gradle.kts (compilerOptions)');
  } else if (settingsPluginContent.indexOf(oldKotlinOptions) !== -1) {
    settingsPluginContent = settingsPluginContent.replace(oldKotlinOptions, newCompilerOptions);
    fs.writeFileSync(path.join(__dirname, settingsPluginGradlePath), settingsPluginContent, 'utf8');
    console.log('   ✅ Applied patch: settings-plugin/build.gradle.kts (compilerOptions)');
  } else {
    console.warn(
      '⚠️  Patch target not found (file may have changed): settings-plugin/build.gradle.kts',
    );
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
  '    val jvmVersion = Jvm.current().javaVersion?.majorVersion',
);

// Patch 2: Suppress deprecation warning in BundleHermesCTask.kt
// Note: Check for exact context to avoid duplicate annotations
var bundleHermesCTaskPath = path.join(
  __dirname,
  'node_modules/@react-native/gradle-plugin/react-native-gradle-plugin/src/main/kotlin/com/facebook/react/tasks/BundleHermesCTask.kt',
);
if (fs.existsSync(bundleHermesCTaskPath)) {
  var content = fs.readFileSync(bundleHermesCTaskPath, 'utf8');
  var searchPattern =
    'File(jsIntermediateSourceMapsDir.get().asFile, "$bundleAssetName.compiler.map")\n\n  private fun runCommand(command: List<Any>) {';
  var replacePattern =
    'File(jsIntermediateSourceMapsDir.get().asFile, "$bundleAssetName.compiler.map")\n\n  @Suppress("DEPRECATION")\n  private fun runCommand(command: List<Any>) {';

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

// ============================================================================
// Boost Configuration for Android
// ============================================================================

console.log('🔍 Configuring Boost for Android...');

var platform = os.platform();
var boostPath = null;

// Try macOS Homebrew first
if (platform === 'darwin') {
  try {
    boostPath = execSync('brew --prefix boost', { stdio: 'pipe', encoding: 'utf-8' }).trim();
    if (boostPath && fs.existsSync(boostPath)) {
      console.log('   ✅ Boost found at ' + boostPath + ' (Homebrew)');
    }
  } catch (e) {
    // Homebrew boost not found on macOS
  }
}

// Try Linux apt installation (for CI environments)
if (!boostPath && platform === 'linux') {
  // Common locations for apt-installed Boost
  var commonBoostPaths = [
    '/usr', // Standard Ubuntu/Debian location
    '/usr/local', // Alternative location
  ];

  for (var i = 0; i < commonBoostPaths.length; i++) {
    var testPath = commonBoostPaths[i];
    var boostInclude = path.join(testPath, 'include', 'boost');

    if (fs.existsSync(boostInclude)) {
      boostPath = testPath;
      console.log('   ✅ Boost found at ' + boostPath + ' (apt)');
      break;
    }
  }
}

// Validation: error if still not found
if (!boostPath) {
  if (platform === 'darwin') {
    console.error('❌ Boost not found. Install: brew install boost');
  } else if (platform === 'linux') {
    console.error('❌ Boost not found. Install: sudo apt-get install libboost-all-dev');
  } else {
    console.error('❌ Boost not found. Platform: ' + platform);
  }
  process.exit(1);
}

// Write to gradle.properties to persist for Gradle builds
var gradlePropertiesPath = path.join(__dirname, 'android', 'gradle.properties');
var gradlePropertiesContent = '';

if (fs.existsSync(gradlePropertiesPath)) {
  gradlePropertiesContent = fs.readFileSync(gradlePropertiesPath, 'utf-8');
}

// Remove any existing REACT_NATIVE_BOOST_PATH entry
gradlePropertiesContent = gradlePropertiesContent
  .split('\n')
  .filter(function (line) {
    return !line.startsWith('REACT_NATIVE_BOOST_PATH=');
  })
  .join('\n');

// Add new REACT_NATIVE_BOOST_PATH
if (!gradlePropertiesContent.endsWith('\n') && gradlePropertiesContent.length > 0) {
  gradlePropertiesContent += '\n';
}
gradlePropertiesContent += 'REACT_NATIVE_BOOST_PATH=' + boostPath + '\n';

fs.writeFileSync(gradlePropertiesPath, gradlePropertiesContent);
console.log('   🔧 Wrote REACT_NATIVE_BOOST_PATH=' + boostPath + ' to gradle.properties');
console.log('   ℹ️  Gradle will use local Boost instead of downloading\n');

// Step 2.5: Configure OAuth for Employee Agent (async)
async function configureOAuthStep() {
  if (target === 'employee' || target === 'all') {
    console.log('\n🔐 Step 2.5/3: Configuring OAuth (Employee Agent only)...\n');

    try {
      var oauthConfig = await interactiveOAuth.promptOAuthConfig();

      if (oauthConfig) {
        var bootconfigPath = path.join(
          __dirname,
          'android/app/src/employeeAgent/res/values/bootconfig.xml',
        );
        console.log('   📝 Updating bootconfig.xml...');

        bootconfig.backupBootconfig(bootconfigPath);
        var result = bootconfig.updateAndroidBootconfig(bootconfigPath, oauthConfig);

        if (result.modified) {
          console.log('   ✅ OAuth configuration updated successfully\n');
        }

        if (result.warnings.length > 0) {
          console.warn('   ⚠️  Warnings during configuration:');
          result.warnings.forEach(function (warn) {
            console.warn('      • ' + warn);
          });
          console.log('');
        }

        bootconfig.printSecurityWarning();
      }
    } catch (err) {
      console.error('❌ Failed to configure OAuth: ' + err.message);
      process.exit(1);
    }
  }
}

// Run OAuth configuration (async)
(async function () {
  await configureOAuthStep();

  // Continue with remaining steps
  continueInstallation();
})();

function continueInstallation() {
  // Build react-native-force for Employee Agent (provides Mobile SDK React Native bridge)
  if (target === 'employee' || target === 'all') {
    console.log('\n📦 Building react-native-force (Mobile SDK React Native bridge)...');
    try {
      execSync('npm run build:force', { stdio: [0, 1, 2] });
    } catch (e) {
      console.warn('⚠️  build:force failed (optional if already built)');
    }
  }

  console.log('\n✅ Android setup complete.');
  if (target === 'service') {
    console.log('   🚀 Service Agent ready: npm run android:service');
  } else if (target === 'employee') {
    console.log('   🚀 Employee Agent ready: npm run android:employee');
  } else {
    console.log('   🚀 Both apps ready:');
    console.log('      npm run android:service  (Service Agent)');
    console.log('      npm run android:employee (Employee Agent)');
  }
} // End of continueInstallation()
