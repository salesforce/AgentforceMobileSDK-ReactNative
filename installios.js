#!/usr/bin/env node

var packageJson = require('./package.json');
var execSync = require('child_process').execSync;
var path = require('path');
var fs = require('fs');

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

console.log('📦 Installing npm dependencies...');
try {
  execSync('npm install --legacy-peer-deps --ignore-scripts', { stdio: [0, 1, 2] });
} catch (e) {
  console.error('❌ npm install failed. Try: npm install --legacy-peer-deps --ignore-scripts');
  process.exit(1);
}

// Build react-native-force for Employee Agent (provides Mobile SDK React Native bridge)
if (target === 'employee' || target === 'all') {
  console.log('\n📦 Building react-native-force (Mobile SDK React Native bridge)...');
  try {
    execSync('npm run build:force', { stdio: [0, 1, 2] });
  } catch (e) {
    console.warn('⚠️  build:force failed (optional if already built)');
  }
}

console.log('\n🔧 Configuring Node.js path for Xcode...');
var nodePath = process.execPath;
if (!nodePath || !fs.existsSync(nodePath)) {
  try {
    nodePath = execSync('which node', { encoding: 'utf-8' }).trim();
  } catch (e) {
    try {
      nodePath = execSync('command -v node', { encoding: 'utf-8' }).trim();
    } catch (e2) {
      console.error('Could not find Node.js path. Set NODE_BINARY in ios/.xcode.env');
      process.exit(1);
    }
  }
}
if (!fs.existsSync(nodePath)) {
  console.error('Node path ' + nodePath + ' does not exist. Set NODE_BINARY in ios/.xcode.env');
  process.exit(1);
}
console.log('   NODE_BINARY=' + nodePath);
execSync('echo export NODE_BINARY=' + nodePath + ' > .xcode.env', { stdio: [0, 1, 2], cwd: 'ios' });
console.log('✅ Created ios/.xcode.env');

console.log('\n📝 Generating Xcode project with xcodegen...');
try {
  execSync('xcodegen generate', { stdio: [0, 1, 2], cwd: 'ios' });
  console.log('✅ Xcode project generated');
} catch (e) {
  console.error('❌ xcodegen generation failed. Ensure xcodegen is installed: brew install xcodegen');
  process.exit(1);
}

console.log('\n🍎 Installing CocoaPods dependencies...');
try {
  var env = { ...process.env };
  delete env.NODE_EXTRA_CA_CERTS;
  env.NODE_NO_WARNINGS = '1';
  env.INSTALL_TARGET = target; // Tell Podfile which target(s) to install
  execSync('pod install', { stdio: [0, 1, 2], cwd: 'ios', env: env });
  console.log('✅ CocoaPods installed');
} catch (e) {
  console.error('❌ pod install failed. Try: cd ios && pod install --repo-update');
  process.exit(1);
}

console.log('\n✅ iOS setup complete!');
if (target === 'service') {
  console.log('   🚀 Service Agent ready: npm run ios:service');
} else if (target === 'employee') {
  console.log('   🚀 Employee Agent ready: npm run ios:employee');
} else {
  console.log('   🚀 Both apps ready:');
  console.log('      npm run ios:service  (Service Agent)');
  console.log('      npm run ios:employee (Employee Agent)');
}
