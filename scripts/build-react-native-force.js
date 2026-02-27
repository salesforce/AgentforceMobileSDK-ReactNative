#!/usr/bin/env node

/*
 Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * Build react-native-force (Salesforce Mobile SDK React Native bridge) when installed from Git.
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
  console.log('react-native-force not found, skipping build');
  process.exit(0);
}

if (fs.existsSync(path.join(forcePath, 'dist', 'index.js'))) {
  console.log('react-native-force already built, skipping');
  process.exit(0);
}

console.log('Building react-native-force (Salesforce Mobile SDK React Native bridge)...');

try {
  execSync('npm install react-native@0.74.7 --no-save --legacy-peer-deps', {
    cwd: forcePath,
    stdio: 'inherit',
  });
  execSync('npm run build', {
    cwd: forcePath,
    stdio: 'inherit',
  });
  console.log('✅ react-native-force build complete.');
} catch (err) {
  console.error('❌ react-native-force build failed:', err.message);
  process.exit(1);
}
