#!/usr/bin/env node

var readline = require('readline');

function isCIEnvironment() {
  if (!process.stdin.isTTY) {
    return true;
  }

  var ciEnvVars = [
    'CI',
    'CONTINUOUS_INTEGRATION',
    'GITHUB_ACTIONS',
    'GITLAB_CI',
    'CIRCLECI',
    'TRAVIS',
  ];
  return ciEnvVars.some(function (envVar) {
    return process.env[envVar];
  });
}

function createInterface() {
  return readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
}

function prompt(rl, question) {
  return new Promise(function (resolve) {
    rl.question(question, function (answer) {
      resolve(answer.trim());
    });
  });
}

function isValidUrl(url) {
  try {
    new URL(url);
    return true;
  } catch (e) {
    return false;
  }
}

async function promptOAuthConfig() {
  if (isCIEnvironment()) {
    console.log('   ℹ️  CI environment detected - skipping OAuth configuration\n');
    return null;
  }

  var rl = createInterface();

  try {
    console.log('\n📋 OAuth Configuration');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    var configure = await prompt(rl, 'Configure OAuth credentials now? (y/n): ');

    if (configure.toLowerCase() !== 'y' && configure.toLowerCase() !== 'yes') {
      console.log('\n⏭️  Skipping - you can manually edit bootconfig later.\n');
      rl.close();
      return null;
    }

    console.log('');
    var config = {};

    while (true) {
      config.consumerKey = await prompt(rl, '🔑 OAuth Consumer Key: ');
      if (config.consumerKey && config.consumerKey.length > 0) {
        break;
      }
      console.log('   ❌ Cannot be empty');
    }

    while (true) {
      config.redirectUri = await prompt(rl, '🔗 OAuth Redirect URI: ');
      if (config.redirectUri && isValidUrl(config.redirectUri)) {
        break;
      }
      console.log('   ❌ Must be a valid URL');
    }

    var scopesInput = await prompt(rl, '📝 OAuth Scopes (default: web,api,sfap_api): ');
    config.scopes = scopesInput.length > 0 ? scopesInput : 'web,api,sfap_api';

    var scopeList = config.scopes
      .split(',')
      .map(function (s) {
        return s.trim();
      })
      .filter(Boolean);
    if (scopeList.length === 0) {
      config.scopes = 'web,api,sfap_api';
    }

    console.log('\n✅ Configuration ready');
    console.log('   Key: ' + config.consumerKey.substring(0, 20) + '...');
    console.log('   URI: ' + config.redirectUri);
    console.log('   Scopes: ' + config.scopes + '\n');

    rl.close();
    return config;
  } catch (error) {
    rl.close();
    throw error;
  }
}

module.exports = {
  promptOAuthConfig: promptOAuthConfig,
};
