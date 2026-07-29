import { chromium, type BrowserContext, type Page } from 'patchright';

export async function launchJailed(
  cookiesDir: string,
  opts: { headless?: boolean } = {},
): Promise<BrowserContext> {
  const executablePath = process.env.KEYFARM_CHROMIUM;
  if (!executablePath) throw new Error('KEYFARM_CHROMIUM env not set');
  // The jail wrapper binds KEYFARM_PROFILE rw at the same path patchright passes
  // as --user-data-dir, so both must agree on cookiesDir.
  process.env.KEYFARM_PROFILE = cookiesDir;
  return chromium.launchPersistentContext(cookiesDir, {
    executablePath,
    headless: opts.headless ?? true,
    // bwrap is the sandbox; disable chromium's own (can't nest in bwrap userns).
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
    ignoreDefaultArgs: ['--disable-component-update'],
  });
}

export async function page(ctx: BrowserContext): Promise<Page> {
  return ctx.pages()[0] ?? (await ctx.newPage());
}
