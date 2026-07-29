import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { launchJailed, page } from './keyfarm.ts';
import type { Page } from 'patchright';

export async function runScript(cookiesDir: string, scriptPath: string): Promise<void> {
  const mod = (await import(pathToFileURL(resolve(scriptPath)).href)) as {
    run?: (p: Page) => Promise<void>;
  };
  if (typeof mod.run !== 'function') {
    throw new Error(`${scriptPath} must export async function run(page)`);
  }
  const ctx = await launchJailed(cookiesDir, { headless: process.env.KEYFARM_HEADLESS !== '0' });
  try {
    await mod.run(await page(ctx));
  } finally {
    await ctx.close();
  }
}

// CLI: runner.ts <cookies-dir> <script>
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [, , cookiesDir, scriptPath] = process.argv;
  if (!cookiesDir || !scriptPath) {
    console.error('usage: runner.ts <cookies-dir> <script>');
    process.exit(1);
  }
  runScript(cookiesDir, scriptPath).catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
