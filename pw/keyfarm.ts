import { resolve } from 'node:path';
import { chromium, type BrowserContext, type Page } from 'patchright';

export async function launchJailed(
  cookiesDir: string,
  opts: { headless?: boolean } = {},
): Promise<BrowserContext> {
  const executablePath = process.env.KEYFARM_CHROMIUM;
  if (!executablePath) throw new Error('KEYFARM_CHROMIUM env not set');
  // patchright requires an absolute userDataDir, and bwrap --bind needs an
  // absolute path too, so resolve relative cookiesDir (e.g. "./cookies") here.
  const dir = resolve(cookiesDir);
  // The jail wrapper binds KEYFARM_PROFILE rw at the same path patchright passes
  // as --user-data-dir, so both must agree on dir. Scoped to this subprocess's
  // env (not process.env) so we don't mutate global state.
  return chromium.launchPersistentContext(dir, {
    executablePath,
    headless: opts.headless ?? true,
    // bwrap is the sandbox; disable chromium's own (can't nest in bwrap userns).
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
    env: { ...process.env, KEYFARM_PROFILE: dir },
  });
}

export async function page(ctx: BrowserContext): Promise<Page> {
  return ctx.pages()[0] ?? (await ctx.newPage());
}
