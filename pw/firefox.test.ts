import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { launchJailed, page } from './keyfarm.ts';

// Falling back to jailed/Juggler Firefox or injecting Playwright prefs breaks this test.
test('stock Firefox drives frames, downloads, and reuses a profile without rewriting user.js', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'keyfarm-stock-firefox-'));
  const userPrefs = 'user_pref("security.fileuri.strict_origin_policy", true);\n';
  writeFileSync(join(dir, 'user.js'), userPrefs);
  const server = createServer((request, response) => {
    if (request.url === '/download') {
      response.setHeader('content-disposition', 'attachment; filename="original.png"');
      response.end('test-image');
    } else {
      response.setHeader('content-type', 'text/html');
      response.end(request.url === '/frame'
        ? '<label>Prompt<textarea></textarea></label><a href="/download" download>Download</a>'
        : '<title>stock Firefox</title><iframe title="Space app" src="/frame"></iframe>');
    }
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address() as { port: number };
  const url = `http://127.0.0.1:${port}`;
  try {
    const ctx = await launchJailed(dir, { headless: true, firefoxProfile: dir });
    try {
      const p = await page(ctx);
      await p.goto(url);
      assert.equal(await p.title(), 'stock Firefox');
      const frame = p.frameLocator('iframe');
      await frame.getByLabel('Prompt').fill('profile test');
      assert.equal(await frame.getByLabel('Prompt').inputValue(), 'profile test');
      const downloadPromise = p.waitForEvent('download');
      await frame.getByRole('link', { name: 'Download' }).click();
      const download = await downloadPromise;
      assert.equal(download.suggestedFilename(), 'original.png');
      await download.saveAs(join(dir, 'saved.png'));
      assert.equal(readFileSync(join(dir, 'saved.png'), 'utf8'), 'test-image');
      await ctx.addCookies([{ url, name: 'profile-test', value: 'persisted', expires: Date.now() / 1000 + 3600 }]);
    } finally {
      await ctx.close();
    }
    assert.equal(readFileSync(join(dir, 'user.js'), 'utf8'), userPrefs);
    const reopened = await launchJailed(dir, { headless: true, firefoxProfile: dir });
    try {
      assert.equal((await reopened.cookies(url)).find(c => c.name === 'profile-test')?.value, 'persisted');
    } finally {
      await reopened.close();
    }
    assert.equal(readFileSync(join(dir, 'user.js'), 'utf8'), userPrefs);
    assert.doesNotMatch(readFileSync(join(dir, 'prefs.js'), 'utf8'), /user_pref\("browser.safebrowsing.malware.enabled", false\)/);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    rmSync(dir, { recursive: true, force: true });
  }
});
