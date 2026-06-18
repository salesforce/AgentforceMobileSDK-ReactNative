/**
 * Tests for scripts/update-bootconfig.js.
 *
 * Operates on bootconfig fixtures written into an OS temp dir so the real
 * project files are never touched.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');

const {
  backupBootconfig,
  updateIOSBootconfig,
  updateAndroidBootconfig,
} = require('../update-bootconfig');

const IOS_PLIST = `<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>remoteAccessConsumerKey</key>
\t<string>OLD_KEY</string>
\t<key>oauthRedirectURI</key>
\t<string>old://redirect</string>
\t<key>oauthScopes</key>
\t<array>
\t\t<string>old</string>
\t</array>
</dict>
</plist>
`;

const ANDROID_XML = `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="remoteAccessConsumerKey">OLD_KEY</string>
    <string name="oauthRedirectURI">old://redirect</string>
    <string-array name="oauthScopes">
        <item>old</item>
    </string-array>
</resources>
`;

const config = {
  consumerKey: 'NEW_KEY_123',
  redirectUri: 'sfdc:///oauth/done',
  scopes: 'web, api ,refresh_token',
};

let tmpDir;

beforeEach(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'bootconfig-'));
});

afterEach(() => {
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

describe('updateIOSBootconfig', () => {
  it('replaces consumer key, redirect URI, and scopes', () => {
    const file = path.join(tmpDir, 'bootconfig.plist');
    fs.writeFileSync(file, IOS_PLIST);

    const result = updateIOSBootconfig(file, config);
    const content = fs.readFileSync(file, 'utf8');

    expect(result.modified).toBe(true);
    expect(result.warnings).toEqual([]);
    expect(content).toContain('<string>NEW_KEY_123</string>');
    expect(content).toContain('<string>sfdc:///oauth/done</string>');
    // scopes are split, trimmed, and re-emitted as individual <string> entries
    expect(content).toContain('<string>web</string>');
    expect(content).toContain('<string>api</string>');
    expect(content).toContain('<string>refresh_token</string>');
    expect(content).not.toContain('<string>old</string>');
  });

  it('records warnings for patterns that are absent', () => {
    const file = path.join(tmpDir, 'partial.plist');
    fs.writeFileSync(file, '<plist><dict></dict></plist>');

    const result = updateIOSBootconfig(file, config);

    expect(result.modified).toBe(false);
    expect(result.warnings).toEqual(
      expect.arrayContaining([
        'remoteAccessConsumerKey pattern not found',
        'oauthRedirectURI pattern not found',
        'oauthScopes pattern not found',
      ]),
    );
  });

  it('throws when the file does not exist', () => {
    expect(() => updateIOSBootconfig(path.join(tmpDir, 'missing.plist'), config)).toThrow(
      /not found/,
    );
  });
});

describe('updateAndroidBootconfig', () => {
  it('replaces consumer key, redirect URI, and scopes as <item> entries', () => {
    const file = path.join(tmpDir, 'bootconfig.xml');
    fs.writeFileSync(file, ANDROID_XML);

    const result = updateAndroidBootconfig(file, config);
    const content = fs.readFileSync(file, 'utf8');

    expect(result.modified).toBe(true);
    expect(result.warnings).toEqual([]);
    expect(content).toContain('<string name="remoteAccessConsumerKey">NEW_KEY_123</string>');
    expect(content).toContain('<string name="oauthRedirectURI">sfdc:///oauth/done</string>');
    expect(content).toContain('<item>web</item>');
    expect(content).toContain('<item>api</item>');
    expect(content).toContain('<item>refresh_token</item>');
    expect(content).not.toContain('<item>old</item>');
  });

  it('throws when the file does not exist', () => {
    expect(() => updateAndroidBootconfig(path.join(tmpDir, 'missing.xml'), config)).toThrow(
      /not found/,
    );
  });
});

describe('backupBootconfig', () => {
  it('writes an iOS backup next to the original file', () => {
    const file = path.join(tmpDir, 'bootconfig.plist');
    fs.writeFileSync(file, IOS_PLIST);

    const backupPath = backupBootconfig(file);

    expect(backupPath).toBe(file + '.backup');
    expect(fs.existsSync(backupPath)).toBe(true);
    expect(fs.readFileSync(backupPath, 'utf8')).toBe(IOS_PLIST);
  });

  it('writes an Android backup outside the res/ directory', () => {
    // The helper keys on the path containing "android" and "/res/".
    const flavorDir = path.join(tmpDir, 'android', 'app', 'src', 'employeeAgent');
    const resDir = path.join(flavorDir, 'res', 'values');
    fs.mkdirSync(resDir, { recursive: true });
    const file = path.join(resDir, 'bootconfig.xml');
    fs.writeFileSync(file, ANDROID_XML);

    const backupPath = backupBootconfig(file);

    expect(backupPath).toBe(path.join(flavorDir, 'bootconfig.xml.backup'));
    expect(fs.existsSync(backupPath)).toBe(true);
  });

  it('throws when the source file is missing', () => {
    expect(() => backupBootconfig(path.join(tmpDir, 'nope.plist'))).toThrow(/not found/);
  });
});
