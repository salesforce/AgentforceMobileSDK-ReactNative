#!/usr/bin/env node

var packageJson = require('./package.json');
var execSync = require('child_process').execSync;
var path = require('path');
var fs = require('fs');
var interactiveOAuth = require('./scripts/interactive-oauth');
var bootconfig = require('./scripts/update-bootconfig');

// ============================================================================
// Validation Functions
// ============================================================================

function validateEnvironment() {
  console.log('🔍 Validating environment...\n');

  var errors = [];
  var warnings = [];

  // Check xcodegen
  try {
    execSync('which xcodegen', { stdio: 'pipe' });
    console.log('   ✅ xcodegen found');
  } catch (e) {
    errors.push('xcodegen not found. Install: brew install xcodegen');
  }

  // Check pod
  try {
    execSync('which pod', { stdio: 'pipe' });
    console.log('   ✅ CocoaPods found');
  } catch (e) {
    errors.push('CocoaPods not found. Install: sudo gem install cocoapods');
  }

  // Check Boost
  try {
    execSync('brew --prefix boost', { stdio: 'pipe' });
    console.log('   ✅ Boost found');
  } catch (e) {
    errors.push('Boost not found. Install: brew install boost');
  }

  // Check Node version
  var nodeVersion = process.versions.node.split('.')[0];
  if (parseInt(nodeVersion) < 18) {
    warnings.push('Node version ' + nodeVersion + ' detected. Node 18+ recommended.');
  } else {
    console.log('   ✅ Node.js ' + process.versions.node);
  }

  // Report errors
  if (errors.length > 0) {
    console.error('\n❌ Environment validation failed:\n');
    errors.forEach(function (err) {
      console.error('   • ' + err);
    });
    process.exit(1);
  }

  // Report warnings
  if (warnings.length > 0) {
    console.warn('\n⚠️  Warnings:\n');
    warnings.forEach(function (warn) {
      console.warn('   • ' + warn);
    });
  }

  console.log('\n✅ Environment validation passed\n');
}

// ============================================================================
// Main Installation Flow
// ============================================================================

// Check for help flag
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log('\n╔═══════════════════════════════════════════════════════════════╗');
  console.log('║       iOS Multi-App Installation - AgentforceSDK              ║');
  console.log('╚═══════════════════════════════════════════════════════════════╝\n');
  console.log('Usage:');
  console.log('  node installios.js [target]\n');
  console.log('Target:');
  console.log('  service        Install Service Agent only (no Mobile SDK)');
  console.log('  employee       Install Employee Agent only (with Mobile SDK)');
  console.log('  all            Install both apps (default)\n');
  console.log('Examples:');
  console.log('  node installios.js service   # Service Agent only');
  console.log('  node installios.js employee  # Employee Agent only');
  console.log('  node installios.js all       # Both apps');
  console.log('  node installios.js           # Same as "all"\n');
  console.log('OAuth Configuration:');
  console.log('  When installing Employee Agent, you will be prompted to configure');
  console.log('  OAuth credentials interactively during installation.\n');
  process.exit(0);
}

// Parse target argument: service, employee, all (default: all)
var target = process.argv[2] || 'all';
if (!['service', 'employee', 'all'].includes(target)) {
  console.error('❌ Invalid target: ' + target);
  console.error('   Usage: node installios.js [service|employee|all]');
  console.error('   Examples:');
  console.error('     node installios.js service   # Service Agent only (no Mobile SDK)');
  console.error('     node installios.js employee  # Employee Agent only (with Mobile SDK)');
  console.error('     node installios.js all       # Both apps (with Mobile SDK)');
  console.error('     node installios.js           # Same as "all" (backward compatible)');
  process.exit(1);
}

console.log('\n╔═══════════════════════════════════════════════════════════════╗');
console.log('║       iOS Multi-App Installation - AgentforceSDK              ║');
console.log('╚═══════════════════════════════════════════════════════════════╝\n');

// Validate environment before starting
validateEnvironment();

// Display installation plan
console.log('📋 Installation Plan:');
console.log('   Target: ' + target);
console.log('   Mobile SDK: ' + (target === 'service' ? '❌ Not included' : '✅ Included'));
console.log(
  '   Apps to build: ' +
    (target === 'all'
      ? 'ServiceAgent + EmployeeAgent'
      : target === 'service'
      ? 'ServiceAgent'
      : 'EmployeeAgent'),
);
console.log('\n🔧 Steps:');
console.log('   1. Install npm dependencies');
console.log('   2. Apply patches (patch-package)');
if (target !== 'service') {
  console.log('   2.5. Configure OAuth (Employee Agent)');
  console.log('   3. Build react-native-force (Mobile SDK bridge)');
}
console.log('   4. Configure Node.js path');
console.log('   5. Generate Xcode project (xcodegen)');
console.log('   6. Install CocoaPods');
console.log('   7. Add Pods target dependencies');
console.log('   8. Save lock files');
console.log('\n▶️  Starting installation...\n');
console.log('═══════════════════════════════════════════════════════════════\n');

// Step 1: Install npm dependencies
console.log('📦 Step 1/8: Installing npm dependencies...');
try {
  execSync('npm install --legacy-peer-deps --ignore-scripts', { stdio: [0, 1, 2] });
  console.log('✅ Step 1/8: npm dependencies installed\n');
} catch (e) {
  console.error('❌ npm install failed. Try: npm install --legacy-peer-deps --ignore-scripts');
  process.exit(1);
}

// Step 2: Apply patches
console.log('📦 Step 2/8: Applying patches (e.g. cli-platform-apple for multi-scheme iOS)...');
try {
  execSync('npx patch-package', { stdio: [0, 1, 2] });
  console.log('✅ Step 2/8: Patches applied\n');
} catch (e) {
  console.warn('⚠️  patch-package failed (optional if no patches)\n');
}

// Step 2.5: Configure OAuth for Employee Agent (async)
async function configureOAuthStep() {
  if (target === 'employee' || target === 'all') {
    console.log('🔐 Step 2.5/8: Configuring OAuth (Employee Agent only)...\n');

    try {
      var oauthConfig = await interactiveOAuth.promptOAuthConfig();

      if (oauthConfig) {
        var bootconfigPath = path.join(__dirname, 'ios/EmployeeAgent/bootconfig.plist');
        console.log('   📝 Updating bootconfig.plist...');

        bootconfig.backupBootconfig(bootconfigPath);
        var result = bootconfig.updateIOSBootconfig(bootconfigPath, oauthConfig);

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
  // Step 3: Build react-native-force for Employee Agent (provides Mobile SDK React Native bridge)
  if (target === 'employee' || target === 'all') {
    console.log('📦 Step 3/8: Building react-native-force (Mobile SDK React Native bridge)...');
    try {
      execSync('npm run build:force', { stdio: [0, 1, 2] });
      console.log('✅ Step 3/8: react-native-force built\n');
    } catch (e) {
      console.warn('⚠️  build:force failed (optional if already built)\n');
    }
  } else {
    console.log('⏭️  Step 3/8: Skipped (Service Agent does not need Mobile SDK bridge)\n');
  }

  // Step 4: Configure Node.js path
  console.log('🔧 Step 4/8: Configuring Node.js path for Xcode...');
  var nodePath = process.execPath;
  if (!nodePath || !fs.existsSync(nodePath)) {
    try {
      nodePath = execSync('which node', { encoding: 'utf-8' }).trim();
    } catch (e) {
      try {
        nodePath = execSync('command -v node', { encoding: 'utf-8' }).trim();
      } catch (e2) {
        console.error('❌ Could not find Node.js path. Set NODE_BINARY in ios/.xcode.env');
        process.exit(1);
      }
    }
  }
  if (!fs.existsSync(nodePath)) {
    console.error(
      '❌ Node path ' + nodePath + ' does not exist. Set NODE_BINARY in ios/.xcode.env',
    );
    process.exit(1);
  }
  console.log('   NODE_BINARY=' + nodePath);
  execSync('echo export NODE_BINARY=' + nodePath + ' > .xcode.env', { stdio: 'pipe', cwd: 'ios' });
  console.log('✅ Step 4/8: Node.js path configured (ios/.xcode.env)\n');

  // Use separate Podfiles: service = subset, employee/all = full (employee Podfile)
  var podfileName = target === 'service' ? 'Podfile.service' : 'Podfile.employee';
  var lockFileName = target === 'service' ? 'Podfile.service.lock' : 'Podfile.employee.lock';
  var iosDir = path.join(__dirname, 'ios');
  var sourcePodfile = path.join(iosDir, podfileName);
  var activePodfile = path.join(iosDir, 'Podfile');
  var activeLock = path.join(iosDir, 'Podfile.lock');
  var sourceLock = path.join(iosDir, lockFileName);

  console.log('📋 Preparing Podfile for target: ' + target);
  console.log(
    '   Using: ' +
      podfileName +
      ' (' +
      (target === 'service' ? 'Service Agent only' : 'Employee Agent / both apps') +
      ')',
  );
  fs.copyFileSync(sourcePodfile, activePodfile);
  if (fs.existsSync(sourceLock)) {
    fs.copyFileSync(sourceLock, activeLock);
    console.log('   Restored: ' + lockFileName);
  } else {
    if (fs.existsSync(activeLock)) {
      fs.unlinkSync(activeLock);
    }
    console.log('   No existing lock file found (will generate new one)');
  }
  console.log('');

  // Step 5: Generate Xcode project
  console.log('📝 Step 5/8: Generating Xcode project with xcodegen...');
  try {
    execSync('xcodegen generate', { stdio: [0, 1, 2], cwd: 'ios' });
    console.log('✅ Step 5/8: Xcode project generated\n');
  } catch (e) {
    console.error(
      '❌ xcodegen generation failed. Ensure xcodegen is installed: brew install xcodegen',
    );
    process.exit(1);
  }

  // Step 6: Install CocoaPods
  console.log('🍎 Step 6/8: Installing CocoaPods dependencies...');
  console.log('   This may take a few minutes...\n');
  try {
    var env = { ...process.env };
    delete env.NODE_EXTRA_CA_CERTS;
    env.NODE_NO_WARNINGS = '1';
    execSync('pod install', { stdio: [0, 1, 2], cwd: 'ios', env: env });
    console.log('\n✅ Step 6/8: CocoaPods installed\n');
  } catch (e) {
    console.error('\n❌ pod install failed. Try: cd ios && pod install --repo-update');
    process.exit(1);
  }

  // Step 7: Pods target dependencies added automatically via Podfile.common.rb post_install hook
  console.log('✅ Step 7/8: Pods target dependencies added (via post_install hook)\n');

  // Step 8: Save lock file
  console.log('💾 Step 8/8: Managing lock files...');
  if (fs.existsSync(activeLock)) {
    fs.copyFileSync(activeLock, sourceLock);
    console.log('   ✅ Saved ' + lockFileName);
  } else {
    console.warn('   ⚠️  No Podfile.lock generated (unexpected)');
  }

  console.log('\n═══════════════════════════════════════════════════════════════\n');
  console.log('✅ iOS setup complete!');
  console.log('\n📱 Next steps:\n');
  if (target === 'service') {
    console.log('   🚀 Run Service Agent:');
    console.log('      npm run ios:service\n');
    console.log('   📂 Or open in Xcode:');
    console.log('      open ios/ReactAgentforce.xcworkspace');
    console.log('      Select scheme: ServiceAgent');
  } else if (target === 'employee') {
    console.log('   🚀 Run Employee Agent:');
    console.log('      npm run ios:employee\n');
    console.log('   📂 Or open in Xcode:');
    console.log('      open ios/ReactAgentforce.xcworkspace');
    console.log('      Select scheme: EmployeeAgent');
  } else {
    console.log('   🚀 Run either app:');
    console.log('      npm run ios:service  (Service Agent)');
    console.log('      npm run ios:employee (Employee Agent)\n');
    console.log('   📂 Or open in Xcode:');
    console.log('      open ios/ReactAgentforce.xcworkspace');
    console.log('      Select scheme: ServiceAgent or EmployeeAgent');
  }
  console.log('\n═══════════════════════════════════════════════════════════════\n');
} // End of continueInstallation()
