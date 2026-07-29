# keyfarm — Design Spec

**Date:** 2026-07-29
**Status:** Approved for implementation planning

## 1. Purpose

`keyfarm` is the **generic / technical layer** for driving a jailed, stealthy
browser from Playwright, and for letting an AI maintain that Playwright script
from natural-language instructions.

It is designed to be consumed as a **flake input** by downstream
**functional / website-specific** repos. keyfarm ships the machinery and a
reusable *technical* command; each downstream repo hand-writes its own
*functional* command (the website-specific browser steps) and owns its
generated Playwright script.

Name: cookies are keys, the jail contains them — you farm authenticated
sessions safely.

## 2. Goals / Non-goals

**Goals**
- Launch a **jailed** (bubblewrap) Chromium whose profile is a directory passed
  as a flake app argument (`--user-data-dir`), so a real logged-in session
  persists across runs.
- Run a **Playwright script** against that jailed browser, provided as a flake
  app argument.
- **Stealth is first-class**, default-on: evade Cloudflare Turnstile and similar
  bot-detection via `patchright` (de-fingerprinted Playwright driver).
- Ship a **reusable Claude command** that maintains (creates/updates) the
  Playwright script while executing natural-language instructions, keeping the
  two mirrored.
- Be **composed by downstream flakes** via a `lib.mkApp` helper.

**Non-goals (deliberately cut — YAGNI)**
- No Brave, no camoufox, no Firefox engine for now — **Chromium only**.
- **Never Google Chrome** (proprietary) — not now, not as a fallback.
- No multi-engine abstraction (one engine = patchright). A single
  `launchJailed()` seam is left so a browser swap is a one-liner later.
- No headless "AI runs itself" nix app — the functional-repo maintainer runs
  the harness **by hand**.
- No cookie-file import — the directory **is** the persistent profile.
- No network egress allowlist — the jail is filesystem/process isolation only.
- Turnstile is **not** LLM-solvable (it is ML scoring below the browser:
  TLS/JA3, HTTP/2 framing, Client Hints, IP reputation); no captcha-solving.

## 3. Architecture

Three layers, all shipped by keyfarm:

### A. Nix flake & apps

- **`nix run .#browser -- <cookies-dir>`** — jailed **headful** Chromium against
  `<cookies-dir>` as `--user-data-dir`, **no automation attached**. This is how
  you **farm keys**: open it, log in by hand, close it. Manual login yields the
  cleanest, warmest `cf_clearance` / `__cf_bm` profile (zero automation tells).
- **`nix run .#run -- <cookies-dir> <script.ts>`** — jailed **headless**
  Chromium via **patchright**, same profile, executes the script's exported
  `run(page)`. Deterministic replay, no AI.
- **`nix develop`** — dev shell: node, patchright (pinned), chromium, bubblewrap.
- **`keyfarm.lib.mkApp { cookiesDir; script; browser ? pkgs.chromium; headless ? true }`**
  — lets a downstream flake wire *its* cookies dir + *its* script into its own
  `nix run .#default`. The `browser` arg stays overridable but defaults to
  `pkgs.chromium`; Brave/others are not imported.

### B. Jail + stealth

- **Jail = bubblewrap.** A `writeShellApplication` wraps `pkgs.chromium`: binds
  the Nix store read-only, the cookies dir writable, minimal `/dev` `/proc`
  `/tmp`; host filesystem hidden. Chromium runs **`--no-sandbox` inside bwrap** —
  bwrap *is* the sandbox (Chromium's own userns sandbox can't nest inside
  bwrap's). Network is **not** unshared, so loopback works.
- **Stealth = patchright** (Node), default-on and the only engine. It kills the
  automation tells: no `Runtime.enable`, no `console.enable`, strips
  `--enable-automation`, adds `--disable-blink-features=AutomationControlled`.
  The bwrap wrapper *also* sets these launch flags so stealth holds regardless of
  connection mode.
- The **binary is a normal browser** from a flake input (`pkgs.chromium`),
  `executablePath` → its nix-store path. patchright supplies the *driver*, not
  the binary (its own download is broken under Nix anyway).
- `ponytail:` Chromium's branding fingerprints weaker than a branded browser,
  but patchright handles the *automation* tells (the main lever). If Turnstile
  stays stubborn, point the `browser` input at another **free** browser (Brave,
  etc.) via the `launchJailed()` seam — **never Google Chrome**.

### C. AI harness — technical command + mirroring

keyfarm ships **`commands/keyfarm-maintain.md`** (the technical Claude slash
command). Downstream copies it into `.claude/commands/`. Given a hand-written
**functional command** file + cookies dir + target script path, it instructs the
AI to:

1. Launch/attach the jailed browser (`.#browser`) and read the functional
   command's natural-language steps.
2. Execute those steps live against the jailed browser.
3. **Create or update** the `.ts` script so it deterministically reproduces the
   steps — **each NL step ↔ a code block**, cross-referenced by comment (the
   *mirror*).
4. Verify: close the headful browser, run `nix run .#run`, confirm success
   before finishing.

The technical command **wraps/calls** the functional one. Farming stays manual;
automation reuses the warm profile.

## 4. Script contract

The "playwright script" is a **plain runnable module**, not a test spec (matches
"script executes itself", and sidesteps `@playwright/test`↔patchright
integration risk):

```ts
// task.ts
import type { Page } from 'patchright';
export async function run(page: Page): Promise<void> {
  // step 1: <mirrors functional-command.md step 1>
  await page.goto('https://example.com');
  // ...
}
```

`runner.ts` (the `.#run` entry): parse `[cookiesDir, scriptPath]` →
`launchJailed(cookiesDir, { headless })` → dynamic-import `scriptPath` → call its
`run(page)`. Add `@playwright/test` later only if assertions/reporting are
needed.

## 5. Downstream consumption model

```
functional-repo/                     # website-specific, hand-written
  flake.nix                          # inputs.keyfarm.url = ...; apps via keyfarm.lib.mkApp
  .claude/commands/keyfarm-maintain.md   # copied from keyfarm
  commands/login-and-scrape.md       # hand-written functional command (NL steps)
  task.ts                            # AI-maintained, mirrors the functional command
  cookies/                           # the persistent profile (gitignored)
```

The maintainer: writes the functional command, runs the keyfarm technical
command by hand (Claude Code) to execute it + maintain `task.ts`, then replays
via `nix run .#default` (built from `keyfarm.lib.mkApp`).

## 6. File layout (keyfarm)

```
keyfarm/
  flake.nix              # inputs (nixpkgs; browser overridable=chromium), apps {browser, run}, devShell, lib.mkApp
  nix/jail.nix           # bwrap wrapper around chromium (--no-sandbox + anti-automation flags)
  pw/
    keyfarm.ts           # launchJailed(cookiesDir, {headless}) -> patchright persistent context  (the single seam)
    runner.ts            # .#run entry: [cookiesDir, scriptPath] -> launchJailed -> import(script).run(page)
    package.json         # patchright, pinned via nix
    tsconfig.json
  commands/keyfarm-maintain.md
  templates/task.ts              # scaffold the AI maintains (exports run(page))
  templates/functional-command.md # example hand-written functional command
  README.md
```

## 7. Risks / things to prove first

1. **bwrap ↔ patchright control pipe (primary risk).** Playwright/patchright
   drives the browser over a pipe (fd 3/4). Confirm it survives the bwrap
   namespace. **Fallback:** launch jailed Chromium with
   `--remote-debugging-port` on `127.0.0.1` + `connectOverCDP` (safe from the
   Chrome-136 port restriction because we always use a custom `--user-data-dir`);
   anti-automation flags are set at launch by the wrapper, so stealth holds.
   Prove this before building on it.
2. **patchright under Nix.** Its browser download is broken under Nix (we
   override with `executablePath`), but the npm package itself must be pinned —
   `buildNpmPackage` / `npmlock2nix` with a committed lockfile.
3. **Profile singleton lock.** A Chromium profile allows one instance at a time;
   close the headful farming/authoring browser before `.#run`. Sequential use,
   documented.
4. **cf_clearance is fragile.** Bound to IP + UA + TLS, expires ~30 min. The
   persistent profile keeps trust/`__cf_bm` warm and lowers challenge difficulty,
   but is not a permanent bypass; a datacenter IP still gets hammered.

## 8. Rejected alternatives (for the record)

- **chrome-use** (github.com/leeguooooo/chrome-use) — architecturally opposite:
  drives your *real daily-driver* Chrome for stealth, replaces Playwright, no
  directory-cookie support. Not adopted. Its one useful idea (keep
  `Runtime.enable` off) is exactly what patchright already gives us.
- **camoufox / Brave / Firefox engine** — scope-cut to Chromium-only for now.
- **Headless AI nix app** — the functional maintainer runs the harness by hand.
