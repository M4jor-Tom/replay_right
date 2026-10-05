import { resolve } from 'node:path';
import { firefox, type BrowserContext, type Page } from 'playwright-core';

export async function launchJailed(
  cookiesDir: string,
  opts: { headless?: boolean } = {},
): Promise<BrowserContext> {
  const executablePath = process.env.KEYFARM_BROWSER;
  if (!executablePath) throw new Error('KEYFARM_BROWSER env not set');
  // Playwright and bwrap --bind need an absolute profile path, so resolve
  // relative cookiesDir (e.g. "./cookies") here.
  const dir = resolve(cookiesDir);
  // The jail wrapper binds KEYFARM_PROFILE rw at the same path Playwright uses
  // for the persistent Firefox profile. Scoped to this subprocess's env (not
  // process.env) so we don't mutate global state.
  return firefox.launchPersistentContext(dir, {
    executablePath,
    headless: opts.headless ?? true,
    env: { ...process.env, KEYFARM_PROFILE: dir },
  });
}

export async function page(ctx: BrowserContext): Promise<Page> {
  return ctx.pages()[0] ?? (await ctx.newPage());
}
