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

require('./scripts/patch-react-native-gradle-plugin');

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

// Try Windows installation (BOOST_ROOT, vcpkg, or common install paths)
if (!boostPath && platform === 'win32') {
  var winBoostCandidates = [];

  // 1. BOOST_ROOT env var (de-facto standard override)
  if (process.env.BOOST_ROOT) {
    winBoostCandidates.push(process.env.BOOST_ROOT);
  }

  // 2. vcpkg installations (env var, then common roots), across common triplets
  var vcpkgTriplets = ['x64-windows', 'x86-windows', 'x64-windows-static', 'arm64-windows'];
  var vcpkgRoots = [];
  if (process.env.VCPKG_ROOT) {
    vcpkgRoots.push(process.env.VCPKG_ROOT);
  }
  vcpkgRoots.push('C:\\vcpkg');
  vcpkgRoots.push('C:\\src\\vcpkg');
  if (process.env.USERPROFILE) {
    vcpkgRoots.push(path.join(process.env.USERPROFILE, 'vcpkg'));
  }
  vcpkgRoots.forEach(function (root) {
    vcpkgTriplets.forEach(function (triplet) {
      winBoostCandidates.push(path.join(root, 'installed', triplet));
    });
  });

  // 3. Common manual / Chocolatey install locations
  winBoostCandidates.push('C:\\boost');
  winBoostCandidates.push('C:\\Boost');
  winBoostCandidates.push('C:\\local\\boost');

  for (var j = 0; j < winBoostCandidates.length; j++) {
    var winCandidate = winBoostCandidates[j];
    if (!winCandidate) {
      continue;
    }
    var winBoostInclude = path.join(winCandidate, 'include', 'boost');
    if (fs.existsSync(winBoostInclude)) {
      boostPath = winCandidate;
      console.log('   ✅ Boost found at ' + boostPath + ' (Windows)');
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
  } else if (platform === 'win32') {
    console.error('❌ Boost not found.');
    console.error('   Install via vcpkg: vcpkg install boost');
    console.error('   Or set BOOST_ROOT to a directory containing include\\boost.');
  } else {
    console.error('❌ Boost not found. Platform: ' + platform);
  }
  process.exit(1);
}

// Write to local.properties to persist for Gradle builds
// (React Native reads from System.getenv, so we configure Gradle to export it)
var localPropertiesPath = path.join(__dirname, 'android', 'local.properties');
var localPropertiesContent = '';

if (fs.existsSync(localPropertiesPath)) {
  localPropertiesContent = fs.readFileSync(localPropertiesPath, 'utf-8');
}

// Remove any existing REACT_NATIVE_BOOST_PATH entry
localPropertiesContent = localPropertiesContent
  .split('\n')
  .filter(function (line) {
    return !line.startsWith('REACT_NATIVE_BOOST_PATH=');
  })
  .join('\n');

// Add new REACT_NATIVE_BOOST_PATH
if (!localPropertiesContent.endsWith('\n') && localPropertiesContent.length > 0) {
  localPropertiesContent += '\n';
}
localPropertiesContent += 'REACT_NATIVE_BOOST_PATH=' + boostPath + '\n';

fs.writeFileSync(localPropertiesPath, localPropertiesContent);
console.log('   🔧 Wrote REACT_NATIVE_BOOST_PATH=' + boostPath + ' to local.properties');
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
