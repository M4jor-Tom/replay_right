import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { launchJailed, page } from './keyfarm.ts';
import type { Page } from 'playwright-core';
import { browserArgs } from './browser.ts';

export async function runScript(cookiesDir: string, scriptPath: string, opts: { firefoxProfile?: string } = {}): Promise<void> {
  const mod = (await import(pathToFileURL(resolve(scriptPath)).href)) as {
    run?: (p: Page) => Promise<void>;
  };
  if (typeof mod.run !== 'function') {
    throw new Error(`${scriptPath} must export async function run(page)`);
  }
  const ctx = await launchJailed(cookiesDir, { ...opts, headless: process.env.KEYFARM_HEADLESS !== '0' });
  try {
    await mod.run(await page(ctx));
  } finally {
    await ctx.close();
  }
}

// CLI: runner.ts <cookies-dir> <script> | --browser firefox <profile-name> <script>
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const { args, firefoxProfile } = browserArgs(process.argv.slice(2));
    const [cookiesDir, scriptPath] = firefoxProfile && args.length === 1
      ? [firefoxProfile, args[0]] : args;
    if (!cookiesDir || !scriptPath || args.length > 2) {
      throw new Error('usage: runner.ts <cookies-dir> <script> | --browser firefox <profile-name> <script>');
    }
    await runScript(cookiesDir, scriptPath, { firefoxProfile });
  } catch (error) {
    console.error((error as Error).message);
    process.exit(1);
  }
}
