/**
 * Tests for scripts/generate-app-config.js.
 *
 * The script writes AppConfig.generated.ts to a path relative to its own
 * location, so it is copied into a temp dir (with a fake src/config tree) and
 * run there as a child process — the real generated file is never touched.
 */
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const REAL_SCRIPT = path.join(__dirname, '..', 'generate-app-config.js');

let tmpDir;
let scriptCopy;
let generatedPath;

beforeEach(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'gen-config-'));
  const scriptsDir = path.join(tmpDir, 'scripts');
  fs.mkdirSync(path.join(tmpDir, 'src', 'config'), { recursive: true });
  fs.mkdirSync(scriptsDir, { recursive: true });
  scriptCopy = path.join(scriptsDir, 'generate-app-config.js');
  fs.copyFileSync(REAL_SCRIPT, scriptCopy);
  generatedPath = path.join(tmpDir, 'src', 'config', 'AppConfig.generated.ts');
});

afterEach(() => {
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

function run(target) {
  return execFileSync('node', target == null ? [scriptCopy] : [scriptCopy, target], {
    encoding: 'utf8',
  });
}

describe('generate-app-config', () => {
  it.each(['service', 'employee', 'all'])('writes APP_MODE=%s for a valid target', target => {
    run(target);
    const content = fs.readFileSync(generatedPath, 'utf8');
    expect(content).toContain(`export const APP_MODE = '${target}' as const;`);
  });

  it("defaults to 'all' when no target is given", () => {
    run(null);
    const content = fs.readFileSync(generatedPath, 'utf8');
    expect(content).toContain("export const APP_MODE = 'all' as const;");
  });

  it('exits non-zero on an invalid target', () => {
    expect(() => run('bogus')).toThrow();
    expect(fs.existsSync(generatedPath)).toBe(false);
  });
});
