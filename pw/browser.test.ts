import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, symlinkSync, unlinkSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// Removing named-profile validation or treating privacy as private browsing must fail this check.
test('browser override requires Firefox and resolves an existing named profile', async () => {
  const { browserArgs } = await import('./browser.ts');
  const home = mkdtempSync(join(tmpdir(), 'keyfarm-profiles-'));
  const root = join(home, '.config/mozilla/firefox');
  const profile = join(root, 'privacy');
  mkdirSync(profile, { recursive: true });
  writeFileSync(join(root, 'profiles.ini'), `[Profile0]\nName=privacy\nIsRelative=1\nPath=privacy\n`);
  try {
    assert.deepEqual(browserArgs(['./cookies', 'about:blank'], { HOME: home }), {
      args: ['./cookies', 'about:blank'],
    });
    assert.deepEqual(browserArgs(['--browser', 'firefox', 'privacy', 'about:blank'], { HOME: home }), {
      args: ['about:blank'], firefoxProfile: profile,
    });
    for (const args of [
      ['--browser'], ['--browser', 'firefox'], ['--browser', 'firefox', '--headless'],
      ['--browser', 'chromium', 'privacy'], ['--browser', 'firefox', 'missing'],
    ]) assert.throws(() => browserArgs(args, { HOME: home }));
    symlinkSync(`localhost:+${process.pid}`, join(profile, 'lock'));
    assert.throws(() => browserArgs(['--browser', 'firefox', 'privacy'], { HOME: home }), /close|in use/i);
    unlinkSync(join(profile, 'lock'));
    symlinkSync('localhost:+2147483647', join(profile, 'lock'));
    assert.equal(browserArgs(['--browser', 'firefox', 'privacy'], { HOME: home }).firefoxProfile, profile);
  } finally {
    rmSync(home, { recursive: true, force: true });
  }
});

test('legacy registry supports absolute profile paths and does not create unknown profiles', async () => {
  const { browserArgs } = await import('./browser.ts');
  const home = mkdtempSync(join(tmpdir(), 'keyfarm-profiles-'));
  const root = join(home, '.mozilla/firefox');
  const profile = join(home, 'my profile');
  mkdirSync(root, { recursive: true });
  mkdirSync(profile);
  writeFileSync(join(root, 'profiles.ini'), `[Profile0]\nName=default\nIsRelative=0\nPath=${profile}\n`);
  try {
    assert.equal(browserArgs(['--browser', 'firefox', 'default'], { HOME: home }).firefoxProfile, profile);
    assert.throws(() => browserArgs(['--browser', 'firefox', 'privacy'], { HOME: home }), /profile/i);
  } finally {
    rmSync(home, { recursive: true, force: true });
  }
});
