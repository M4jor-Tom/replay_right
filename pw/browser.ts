import { accessSync, constants, existsSync, readFileSync, readlinkSync, statSync } from 'node:fs';
import { delimiter, dirname, join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export function browserArgs(argv: string[], env: NodeJS.ProcessEnv = process.env): { args: string[]; firefoxProfile?: string } {
  if (argv[0] !== '--browser') return { args: argv };
  const [, browser, name, ...args] = argv;
  if (browser !== 'firefox' || !name || name.startsWith('-')) {
    throw new Error('usage: --browser firefox <profile-name>');
  }
  const home = env.HOME || homedir();
  const registry = [
    join(env.XDG_CONFIG_HOME || join(home, '.config'), 'mozilla/firefox/profiles.ini'),
    join(home, '.mozilla/firefox/profiles.ini'),
  ].find(existsSync);
  if (!registry) throw new Error('Firefox profiles.ini not found');
  let entry: Record<string, string> = {};
  const entries: Record<string, string>[] = [];
  for (const raw of readFileSync(registry, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (line.startsWith('[')) {
      entry = {};
      entries.push(entry);
    } else {
      const equals = line.indexOf('=');
      if (equals > 0) entry[line.slice(0, equals).trim()] = line.slice(equals + 1).trim();
    }
  }
  const profile = entries.find(p => p.Name === name);
  if (!profile?.Path) throw new Error(`Firefox profile "${name}" not found in ${registry}`);
  const dir = profile.IsRelative === '1' ? resolve(dirname(registry), profile.Path) : resolve(profile.Path);
  if (!statSync(dir).isDirectory()) throw new Error(`Firefox profile directory not found: ${dir}`);
  try {
    // Linux Firefox can leave a dangling lock symlink after shutdown. Never
    // delete it: let Firefox handle stale locks and enforce its native lock.
    const lock = readlinkSync(join(dir, 'lock'));
    const pid = Number(lock.match(/:\+?(\d+)$/)?.[1]);
    if (pid > 0) process.kill(pid, 0);
  } catch (error) {
    if (['ENOENT', 'ESRCH'].includes((error as NodeJS.ErrnoException).code || '')) {
      return { args, firefoxProfile: dir };
    }
  }
  throw new Error(`Firefox profile "${name}" is in use; close it first`);
}

export function firefoxExecutable(): string {
  for (const dir of (process.env.PATH || '').split(delimiter)) {
    const file = resolve(dir, 'firefox');
    try {
      accessSync(file, constants.X_OK);
      if (statSync(file).isFile()) return file;
    } catch { /* Try the next PATH entry. */ }
  }
  throw new Error('firefox executable not found on PATH');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const { args, firefoxProfile } = browserArgs(process.argv.slice(2));
    const cookiesDir = firefoxProfile || args.shift();
    if (!cookiesDir) throw new Error('usage: keyfarm-browser <cookies-dir> [args...] | --browser firefox <profile-name> [args...]');
    const dir = resolve(cookiesDir);
    const exe = firefoxProfile ? firefoxExecutable() : process.env.KEYFARM_BROWSER;
    if (!exe) throw new Error('KEYFARM_BROWSER env not set');
    const child = spawnSync(exe, ['-no-remote', '-profile', dir, ...args], {
      stdio: 'inherit', env: { ...process.env, KEYFARM_PROFILE: dir },
    });
    if (child.error) throw child.error;
    process.exit(child.status ?? 1);
  } catch (error) {
    console.error((error as Error).message);
    process.exit(1);
  }
}
