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

console.log('📦 Building react-native-force (Salesforce Mobile SDK)...');
try {
  execSync('npm run build:force', { stdio: [0, 1, 2] });
} catch (e) {
  console.warn('⚠️ build:force failed (optional if already built)');
}

console.log('📦 Installing Android SDK dependencies (Mobile SDK 13.1.1)...');
var sdkDependency = 'SalesforceMobileSDK-Android';
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
  // Avoid Metro / RN confusion from nested package.json and test code
  var hybridPath = path.join(targetDir, 'hybrid');
  var testPath = path.join(targetDir, 'libs', 'test');
  var reactPkgPath = path.join(targetDir, 'libs', 'SalesforceReact', 'package.json');
  if (fs.existsSync(hybridPath)) { rimraf.sync(hybridPath); console.log('   Removed hybrid/'); }
  if (fs.existsSync(testPath)) { rimraf.sync(testPath); console.log('   Removed libs/test/'); }
  if (fs.existsSync(reactPkgPath)) { rimraf.sync(reactPkgPath); console.log('   Removed libs/SalesforceReact/package.json'); }
}

console.log('\n✅ Android SDK clone complete.');
console.log('   The app uses com.salesforce.mobilesdk:SalesforceReact:13.1.1 from Maven Central.');
console.log('   Run: npm run android');
