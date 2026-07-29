import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { launchJailed, page } from './keyfarm.ts';

test('launchJailed drives the jailed chromium over the control pipe', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'keyfarm-'));
  const ctx = await launchJailed(dir, { headless: true });
  try {
    const p = await page(ctx);
    await p.goto('data:text/html,<title>keyfarm-ok</title>');
    assert.equal(await p.title(), 'keyfarm-ok');
  } finally {
    await ctx.close();
  }
});

test('runner imports a script and calls run(page)', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'keyfarm-'));
  const out = join(dir, 'marker.txt');
  const script = join(dir, 'task.ts');
  writeFileSync(script, `
    import { writeFileSync } from 'node:fs';
    export async function run(page) {
      await page.goto('data:text/html,<title>keyfarm-ok</title>');
      writeFileSync(process.env.KEYFARM_OUT, await page.title());
    }
  `);
  process.env.KEYFARM_OUT = out;
  const { runScript } = await import('./runner.ts');
  await runScript(dir, script);
  assert.equal(readFileSync(out, 'utf8'), 'keyfarm-ok');
});
