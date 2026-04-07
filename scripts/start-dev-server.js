#!/usr/bin/env node

/**
 * Dev Server Starter
 * Wrapper script for React Native dev server with intelligent port conflict handling
 */

const { spawn, execSync } = require('child_process');
const readline = require('readline');

const DEFAULT_PORT = 8081;
const ALTERNATE_PORT = 8082;

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Get the current platform
 * @returns {'darwin' | 'linux' | 'win32'} Platform identifier
 */
function getPlatform() {
  return process.platform;
}

/**
 * Check if running in a CI environment
 * @returns {boolean} True if in CI environment
 */
function isCIEnvironment() {
  return !!(process.env.CI || process.env.CONTINUOUS_INTEGRATION || !process.stdin.isTTY);
}

/**
 * Check if a port is currently in use
 * @param {number} port - Port number to check
 * @returns {boolean} True if port is in use
 */
function isPortInUse(port) {
  try {
    const platform = getPlatform();

    if (platform === 'win32') {
      // Windows: Use netstat to check port
      const result = execSync(`netstat -ano | findstr :${port}`, {
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe'],
      });
      return result.trim().length > 0;
    } else {
      // macOS/Linux: Use lsof to check port
      const result = execSync(`lsof -ti:${port}`, {
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe'],
      });
      return result.trim().length > 0;
    }
  } catch (error) {
    // Command fails if port is not in use
    return false;
  }
}

/**
 * Get information about the process using a port
 * @param {number} port - Port number to check
 * @returns {{pid: number, name: string, command: string} | null} Process info or null
 */
function getProcessOnPort(port) {
  try {
    const platform = getPlatform();

    if (platform === 'win32') {
      // Windows: Get PID from netstat
      const netstatResult = execSync(`netstat -ano | findstr :${port}`, {
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe'],
      });

      // Parse PID from netstat output (last column)
      const lines = netstatResult.trim().split('\n');
      if (lines.length === 0) {
        return null;
      }

      const match = lines[0].trim().match(/\s+(\d+)\s*$/);
      if (!match) {
        return null;
      }

      const pid = parseInt(match[1], 10);

      // Get process name using tasklist
      try {
        const tasklistResult = execSync(`tasklist /FI "PID eq ${pid}" /FO CSV /NH`, {
          encoding: 'utf8',
          stdio: ['pipe', 'pipe', 'pipe'],
        });

        const parts = tasklistResult.trim().split(',');
        const name = parts[0] ? parts[0].replace(/"/g, '') : 'unknown';

        return {
          pid,
          name,
          command: name,
        };
      } catch (e) {
        return { pid, name: 'unknown', command: 'unknown' };
      }
    } else {
      // macOS/Linux: Get PID from lsof
      const lsofResult = execSync(`lsof -ti:${port}`, {
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe'],
      });

      const pid = parseInt(lsofResult.trim(), 10);
      if (isNaN(pid)) {
        return null;
      }

      // Get process info using ps
      try {
        const psResult = execSync(`ps -p ${pid} -o comm=`, {
          encoding: 'utf8',
          stdio: ['pipe', 'pipe', 'pipe'],
        });

        const command = psResult.trim();
        const name = command.split('/').pop();

        return {
          pid,
          name,
          command,
        };
      } catch (e) {
        return { pid, name: 'unknown', command: 'unknown' };
      }
    }
  } catch (error) {
    return null;
  }
}

/**
 * Kill a process by PID
 * @param {number} pid - Process ID to kill
 * @param {boolean} force - Use force kill if true
 * @returns {boolean} True if process was killed successfully
 */
function killProcess(pid, force = false) {
  try {
    const platform = getPlatform();

    if (platform === 'win32') {
      // Windows: Use taskkill
      const forceFlag = force ? '/F' : '';
      execSync(`taskkill /PID ${pid} ${forceFlag}`, {
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    } else {
      // macOS/Linux: Use kill
      const signal = force ? '-9' : '';
      execSync(`kill ${signal} ${pid}`, {
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    }

    return true;
  } catch (error) {
    return false;
  }
}

/**
 * Format process information for display
 * @param {{pid: number, name: string, command: string}} processInfo - Process info
 * @returns {string} Formatted string
 */
function formatProcessInfo(processInfo) {
  if (!processInfo) {
    return 'Unknown process';
  }

  return `${processInfo.name} (PID: ${processInfo.pid})`;
}

// ============================================================================
// Main Script Functions
// ============================================================================

/**
 * Start the React Native dev server
 * @param {number} port - Port to start server on
 * @param {string[]} additionalArgs - Additional CLI arguments
 */
function startDevServer(port, additionalArgs = []) {
  console.log(`📦 Starting Metro bundler on port ${port}...\n`);

  // Build the command arguments
  const args = ['start'];

  // Add port flag if not default
  if (port !== DEFAULT_PORT) {
    args.push('--port', port.toString());
  }

  // Add any additional arguments passed through
  args.push(...additionalArgs);

  // Spawn the React Native CLI process
  const devServer = spawn('react-native', args, {
    stdio: 'inherit',
    shell: true,
  });

  devServer.on('error', error => {
    console.error('❌ Failed to start dev server:', error.message);
    process.exit(1);
  });

  devServer.on('exit', code => {
    if (code !== 0 && code !== null) {
      console.error(`❌ Dev server exited with code ${code}`);
      process.exit(code);
    }
  });
}

/**
 * Display conflict information and prompt user for action
 * @param {{pid: number, name: string, command: string}} processInfo - Process info
 * @returns {Promise<string>} User's choice
 */
async function promptUserAction(processInfo) {
  console.log(`⚠️  Port ${DEFAULT_PORT} is already in use by another process\n`);

  const isDevServer = processInfo && processInfo.name === 'node';

  if (processInfo) {
    console.log(`Process: ${formatProcessInfo(processInfo)}`);
    if (processInfo.command && processInfo.command !== 'unknown') {
      console.log(`Command: ${processInfo.command}`);
    }
  } else {
    console.log('Process: Could not determine process details');
  }

  if (!isDevServer && processInfo) {
    console.log("\n⚠️  This doesn't appear to be a Metro dev server");
    console.log('   Consider using option [3] to start on a different port\n');
  }

  console.log('\nWhat would you like to do?\n');
  console.log('[1] Use the existing dev server (recommended if already running)');
  console.log('[2] Kill the existing process and start a new server');
  console.log(
    `[3] Start server on a different port (${ALTERNATE_PORT}) ${
      !isDevServer ? '(recommended)' : ''
    }`,
  );
  console.log('[4] Exit and manage manually\n');

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise(resolve => {
    rl.question('Choice (1-4): ', answer => {
      rl.close();

      const choice = answer.trim();
      switch (choice) {
        case '1':
          resolve('continue');
          break;
        case '2':
          resolve('kill');
          break;
        case '3':
          resolve('different-port');
          break;
        case '4':
          resolve('exit');
          break;
        default:
          console.log(`\n❌ Invalid choice: ${choice}`);
          console.log('Please run the command again and choose 1-4\n');
          resolve('exit');
      }
    });
  });
}

/**
 * Handle user's action choice
 * @param {string} action - User's choice
 * @param {{pid: number, name: string, command: string}} processInfo - Process info
 * @param {string[]} additionalArgs - Additional CLI arguments
 */
async function handleUserAction(action, processInfo, additionalArgs) {
  switch (action) {
    case 'continue':
      console.log('\n✅ Continuing with existing dev server');
      console.log(`   Metro bundler is running on http://localhost:${DEFAULT_PORT}\n`);
      process.exit(0);
      break;

    case 'kill':
      console.log('\n🔄 Stopping existing process...');

      if (!processInfo) {
        console.error('❌ Could not identify the process to kill');
        console.log('   Please manually stop the process and try again\n');
        process.exit(1);
      }

      // Try graceful kill first
      console.log('   Sending termination signal...');
      killProcess(processInfo.pid, false);

      // Wait briefly for graceful shutdown
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Force kill if needed
      console.log('   Ensuring process is terminated...');
      killProcess(processInfo.pid, true);

      // Wait for OS to clean up
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Check if port is now free
      if (isPortInUse(DEFAULT_PORT)) {
        console.log(`\n⚠️  Port ${DEFAULT_PORT} is still in use after killing the process`);
        console.log(`   Starting dev server on port ${ALTERNATE_PORT} instead...\n`);
        startDevServer(ALTERNATE_PORT, additionalArgs);
      } else {
        console.log('✅ Starting new server...\n');
        startDevServer(DEFAULT_PORT, additionalArgs);
      }
      break;

    case 'different-port':
      console.log(`\n🔄 Starting dev server on port ${ALTERNATE_PORT}...\n`);
      console.log(
        `⚠️  Note: You'll need to connect your app to http://localhost:${ALTERNATE_PORT}`,
      );
      console.log('   Update your app configuration if needed\n');
      startDevServer(ALTERNATE_PORT, additionalArgs);
      break;

    case 'exit':
      console.log('\n📋 To manually resolve the port conflict:');
      if (processInfo) {
        console.log(`   1. Kill the process: kill -9 ${processInfo.pid}`);
      } else {
        console.log(`   1. Find the process: lsof -ti:${DEFAULT_PORT}`);
        console.log('   2. Kill the process: kill -9 <PID>');
      }
      console.log('   3. Run npm start again\n');
      process.exit(0);
      break;
  }
}

/**
 * Main function
 */
async function main() {
  try {
    // Get additional arguments passed through npm
    const additionalArgs = process.argv.slice(2);

    // Check if port is in use
    const portInUse = isPortInUse(DEFAULT_PORT);

    if (!portInUse) {
      // Port is free, start normally
      startDevServer(DEFAULT_PORT, additionalArgs);
      return;
    }

    // Port is in use - handle CI environment
    if (isCIEnvironment()) {
      console.error(`❌ Port ${DEFAULT_PORT} is already in use`);
      console.error('   In CI environments, ensure previous processes are cleaned up');
      console.error('   before starting the dev server\n');
      process.exit(1);
    }

    // Get process information
    const processInfo = getProcessOnPort(DEFAULT_PORT);

    // Interactive resolution
    const action = await promptUserAction(processInfo);
    await handleUserAction(action, processInfo, additionalArgs);
  } catch (error) {
    console.error('❌ Unexpected error:', error.message);
    process.exit(1);
  }
}

// Run main function
main();
