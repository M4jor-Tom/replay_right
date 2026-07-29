import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync } from 'node:fs';
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
