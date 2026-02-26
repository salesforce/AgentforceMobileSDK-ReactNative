#!/usr/bin/env node

var packageJson = require('./package.json');
var execSync = require('child_process').execSync;
var path = require('path');
var fs = require('fs');

console.log('📦 Installing npm dependencies...');
try {
  execSync('npm install --legacy-peer-deps --ignore-scripts', { stdio: [0, 1, 2] });
} catch (e) {
  console.error('❌ npm install failed. Try: npm install --legacy-peer-deps --ignore-scripts');
  process.exit(1);
}

console.log('📦 Building react-native-force (Salesforce Mobile SDK)...');
try {
  execSync('npm run build:force', { stdio: [0, 1, 2] });
} catch (e) {
  console.warn('⚠️ build:force failed (optional if already built)');
}

console.log('📦 Installing iOS SDK dependencies (Mobile SDK 13.1.1)...');
var sdkDependency = 'SalesforceMobileSDK-iOS';
var repoUrlWithBranch = packageJson.sdkDependencies && packageJson.sdkDependencies[sdkDependency];
if (!repoUrlWithBranch) {
  console.error('❌ package.json must have sdkDependencies["' + sdkDependency + '"]');
  process.exit(1);
}
var parts = repoUrlWithBranch.split('#');
var repoUrl = parts[0];
var branch = parts.length > 1 ? parts[1] : 'master';
var targetDir = path.join('mobile_sdk', sdkDependency);
if (fs.existsSync(targetDir)) {
  console.log('   ' + targetDir + ' already exists (remove it to refresh and re-run)');
} else {
  execSync('git clone --branch ' + branch + ' --single-branch --depth 1 ' + repoUrl + ' ' + targetDir, { stdio: [0, 1, 2] });
  console.log('✅ Cloned ' + sdkDependency + ' @ ' + branch);
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

console.log('\n🍎 Installing CocoaPods dependencies...');
try {
  var env = { ...process.env };
  delete env.NODE_EXTRA_CA_CERTS;
  env.NODE_NO_WARNINGS = '1';
  execSync('pod install', { stdio: [0, 1, 2], cwd: 'ios', env: env });
  console.log('✅ CocoaPods installed');
} catch (e) {
  console.error('❌ pod install failed. Try: cd ios && pod install --repo-update');
  process.exit(1);
}

console.log('\n✅ iOS setup complete!');
console.log('   Run: npm run ios');
