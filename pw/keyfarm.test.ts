import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { mkdtempSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { launchJailed, page } from './keyfarm.ts';

test('jailed Firefox drives pages, reaches localhost, and persists its profile', async () => {
  const server = createServer((_request, response) => {
    response.setHeader('content-type', 'text/html');
    response.end('<title>keyfarm-firefox-ok</title>');
  });
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address() as AddressInfo;
  const url = `http://127.0.0.1:${address.port}/`;
  const dir = mkdtempSync(join(tmpdir(), 'keyfarm-'));

  try {
    const first = await launchJailed(dir, { headless: true });
    try {
      const p = await page(first);
      const response = await p.goto(url);
      assert.equal(response?.status(), 200);
      assert.equal(await p.title(), 'keyfarm-firefox-ok');
      await first.addCookies([{
        url,
        name: 'keyfarm-profile-test',
        value: 'persisted',
        expires: Math.floor(Date.now() / 1000) + 3600,
      }]);
    } finally {
      await first.close();
    }

    const reopened = await launchJailed(dir, { headless: true });
    try {
      const cookie = (await reopened.cookies(url)).find(({ name }) => name === 'keyfarm-profile-test');
      assert.equal(cookie?.value, 'persisted');
    } finally {
      await reopened.close();
    }
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
});

test('runner imports a script and calls run(page)', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'keyfarm-'));
  const out = join(dir, 'marker.txt');
  const script = join(dir, 'task.ts');
  writeFileSync(script, `
    import { writeFileSync } from 'node:fs';
    export async function run(page) {
      await page.setContent('<title>keyfarm-ok</title>');
      writeFileSync(process.env.KEYFARM_OUT, await page.title());
    }
  `);
  process.env.KEYFARM_OUT = out;
  const { runScript } = await import('./runner.ts');
  await runScript(dir, script);
  assert.equal(readFileSync(out, 'utf8'), 'keyfarm-ok');
});
