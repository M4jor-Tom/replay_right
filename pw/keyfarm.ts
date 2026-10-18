import { resolve } from 'node:path';
import { firefox, type BrowserContext, type Page } from 'playwright-core';
import { firefoxExecutable } from './browser.ts';

export async function launchJailed(
  cookiesDir: string,
  opts: { headless?: boolean; firefoxProfile?: string } = {},
): Promise<BrowserContext> {
  if (opts.firefoxProfile) {
    // Keep Playwright's injected user.js in a disposable directory, not the
    // user's profile. Firefox receives the real profile only in its argv.
    return firefox.launchPersistentContext('', {
      channel: 'moz-firefox',
      executablePath: firefoxExecutable(),
      headless: opts.headless ?? true,
      ignoreDefaultArgs: true,
      args: [
        '--remote-debugging-port=0', '--no-remote', '--profile', opts.firefoxProfile,
        opts.headless === false ? '--foreground' : '--headless',
      ],
    });
  }
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
