#!/usr/bin/env node
/**
 * Build react-native-force (Salesforce Mobile SDK) when installed from Git.
 * The package's prepublish runs in an isolated context without react-native,
 * so we install with --ignore-scripts and run this script to build it using
 * our project's React Native for type resolution.
 */

const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

const root = path.resolve(__dirname, '..');
const forcePath = path.join(root, 'node_modules', 'react-native-force');

if (!fs.existsSync(path.join(forcePath, 'package.json'))) {
  process.exit(0);
}

if (fs.existsSync(path.join(forcePath, 'dist', 'index.js'))) {
  process.exit(0);
}

console.log('Building react-native-force (Salesforce Mobile SDK 13.1)...');

try {
  execSync('npm install react-native@0.74.7 --no-save --legacy-peer-deps', {
    cwd: forcePath,
    stdio: 'inherit',
  });
  execSync('npm run build', {
    cwd: forcePath,
    stdio: 'inherit',
  });
  console.log('react-native-force build done.');
} catch (err) {
  console.error('react-native-force build failed:', err.message);
  process.exit(1);
}
