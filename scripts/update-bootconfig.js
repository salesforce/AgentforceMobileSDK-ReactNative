#!/usr/bin/env node

var fs = require('fs');
var path = require('path');

function backupBootconfig(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error('Bootconfig file not found: ' + filePath);
  }

  // For Android, place backup outside res/ directory to avoid resource merger errors
  // Android resource merger only processes files in res/ directories and expects .xml extension
  var backupPath;
  if (filePath.includes('android') && filePath.includes('/res/')) {
    // Move backup to flavor directory (outside res/)
    var resIndex = filePath.lastIndexOf('/res/');
    var flavorDir = filePath.substring(0, resIndex);
    backupPath = path.join(flavorDir, 'bootconfig.xml.backup');
  } else {
    // For iOS, keep backup next to original file
    backupPath = filePath + '.backup';
  }

  fs.copyFileSync(filePath, backupPath);
  console.log('   📋 Backup created: ' + path.basename(backupPath));
  return backupPath;
}

function updateIOSBootconfig(filePath, config) {
  if (!fs.existsSync(filePath)) {
    throw new Error('iOS bootconfig file not found: ' + filePath);
  }

  var content = fs.readFileSync(filePath, 'utf8');
  var modified = false;
  var warnings = [];

  var consumerKeyPattern = /(<key>remoteAccessConsumerKey<\/key>\s*<string>)[^<]*(<\/string>)/;
  if (consumerKeyPattern.test(content)) {
    content = content.replace(consumerKeyPattern, '$1' + config.consumerKey + '$2');
    modified = true;
  } else {
    warnings.push('remoteAccessConsumerKey pattern not found');
  }

  var redirectUriPattern = /(<key>oauthRedirectURI<\/key>\s*<string>)[^<]*(<\/string>)/;
  if (redirectUriPattern.test(content)) {
    content = content.replace(redirectUriPattern, '$1' + config.redirectUri + '$2');
    modified = true;
  } else {
    warnings.push('oauthRedirectURI pattern not found');
  }

  var scopeList = config.scopes
    .split(',')
    .map(function (s) {
      return s.trim();
    })
    .filter(Boolean);
  var scopesArray = scopeList
    .map(function (scope) {
      return '\t\t<string>' + scope + '</string>';
    })
    .join('\n');

  var scopesPattern = /(<key>oauthScopes<\/key>\s*<array>)([\s\S]*?)(<\/array>)/;
  if (scopesPattern.test(content)) {
    content = content.replace(scopesPattern, '$1\n' + scopesArray + '\n\t$3');
    modified = true;
  } else {
    warnings.push('oauthScopes pattern not found');
  }

  if (modified) {
    fs.writeFileSync(filePath, content, 'utf8');
  }

  return { modified: modified, warnings: warnings };
}

function updateAndroidBootconfig(filePath, config) {
  if (!fs.existsSync(filePath)) {
    throw new Error('Android bootconfig file not found: ' + filePath);
  }

  var content = fs.readFileSync(filePath, 'utf8');
  var modified = false;
  var warnings = [];

  var consumerKeyPattern = /(<string name="remoteAccessConsumerKey">)[^<]*(<\/string>)/;
  if (consumerKeyPattern.test(content)) {
    content = content.replace(consumerKeyPattern, '$1' + config.consumerKey + '$2');
    modified = true;
  } else {
    warnings.push('remoteAccessConsumerKey pattern not found');
  }

  var redirectUriPattern = /(<string name="oauthRedirectURI">)[^<]*(<\/string>)/;
  if (redirectUriPattern.test(content)) {
    content = content.replace(redirectUriPattern, '$1' + config.redirectUri + '$2');
    modified = true;
  } else {
    warnings.push('oauthRedirectURI pattern not found');
  }

  var scopeList = config.scopes
    .split(',')
    .map(function (s) {
      return s.trim();
    })
    .filter(Boolean);
  var scopesArray = scopeList
    .map(function (scope) {
      return '        <item>' + scope + '</item>';
    })
    .join('\n');

  var scopesPattern = /(<string-array name="oauthScopes">)([\s\S]*?)(<\/string-array>)/;
  if (scopesPattern.test(content)) {
    content = content.replace(scopesPattern, '$1\n' + scopesArray + '\n    $3');
    modified = true;
  } else {
    warnings.push('oauthScopes pattern not found');
  }

  if (modified) {
    fs.writeFileSync(filePath, content, 'utf8');
  }

  return { modified: modified, warnings: warnings };
}

function printSecurityWarning() {
  console.log('⚠️  WARNING: Never commit bootconfig files with real credentials!');
  console.log('   Check git status before committing.');
  console.log('   If staged: git restore --staged <file>\n');
}

module.exports = {
  backupBootconfig: backupBootconfig,
  updateIOSBootconfig: updateIOSBootconfig,
  updateAndroidBootconfig: updateAndroidBootconfig,
  printSecurityWarning: printSecurityWarning,
};
