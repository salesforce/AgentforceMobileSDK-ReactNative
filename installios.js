#!/usr/bin/env node

var execSync = require('child_process').execSync;
var path = require('path');
var fs = require('fs');

console.log('📦 Checking JavaScript dependencies...');
if (!fs.existsSync('node_modules')) {
    console.log('   Installing JavaScript dependencies...');
    try {
        execSync('npm install', {stdio:[0,1,2]});
        console.log('✅ JavaScript dependencies installed');
    } catch (e) {
        console.error('❌ npm install failed. Trying with yarn...');
        try {
            execSync('yarn install', {stdio:[0,1,2]});
            console.log('✅ JavaScript dependencies installed with yarn');
        } catch (e2) {
            console.error('❌ Both npm and yarn failed. Please install dependencies manually.');
            process.exit(1);
        }
    }
} else {
    console.log('✅ JavaScript dependencies already installed (skipping)');
}

console.log('\n🔧 Configuring Node.js path for Xcode...');
let nodePath = process.execPath;
if (!nodePath || !fs.existsSync(nodePath)) {
    try {
        nodePath = execSync('which node', { encoding: 'utf-8' }).trim();
    } catch (e) {
        try {
            nodePath = execSync('command -v node', { encoding: 'utf-8' }).trim();
        } catch (e2) {
            console.error('Could not find Node.js path. Please set NODE_BINARY manually in ios/.xcode.env');
            process.exit(1);
        }
    }
}
if (!fs.existsSync(nodePath)) {
    console.error(`Node.js path ${nodePath} does not exist. Please set NODE_BINARY manually in ios/.xcode.env`);
    process.exit(1);
}
console.log(`   Using Node: ${nodePath}`);
execSync(`echo export NODE_BINARY=${nodePath} > .xcode.env`, {stdio:[0,1,2], cwd:'ios'});
console.log('✅ Created ios/.xcode.env');

console.log('\n🍎 Installing iOS CocoaPods dependencies...');
console.log('   This may take a few minutes...');
try {
    // Suppress Node.js warnings that can interfere with CocoaPods
    const env = {...process.env};
    delete env.NODE_EXTRA_CA_CERTS; // Remove certificate warnings
    env.NODE_NO_WARNINGS = '1';
    
    execSync('pod install', {stdio:[0,1,2], cwd:'ios', env: env});
    console.log('✅ CocoaPods dependencies installed');
} catch (e) {
    console.error('❌ pod install failed. Please check the error above.');
    console.error('   Common issues:');
    console.error('   - Make sure CocoaPods is installed: sudo gem install cocoapods');
    console.error('   - Try: cd ios && pod install --repo-update');
    process.exit(1);
}

console.log('\n✅ iOS setup complete!');
console.log('🎯 Next steps:');
console.log('   1. npm run ios');
console.log('   2. Configure Service Agent settings in the app');
console.log('   3. Launch Agentforce conversation');
