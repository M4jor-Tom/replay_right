# keyfarm

Jailed, stealthed browser + AI-maintained Playwright scripts, as a Nix flake.
The technical layer other (functional, website-specific) repos build on.

## Apps
- `nix run .#browser -- <cookies-dir>` — jailed **headful** Chromium for **farming
  keys**: log in by hand; the session persists in `<cookies-dir>`.
- `nix run .#run -- <cookies-dir> <script.ts>` — jailed **headless** replay of a
  `run(page)` script. Deterministic, no AI.
- `nix run .#spawn_consumer_repo -- <name>` — open the functional-command template in `$EDITOR`; on close, scaffold `./<name>` as a keyfarm consumer repo (git-initialized). Override the keyfarm ref with `KEYFARM_REF=`.
- `nix develop` — dev shell (node, chromium, bubblewrap, patchright).

## Downstream use
Add keyfarm as a flake input and compose an app (see `templates/consumer-flake.nix`):
`keyfarm.lib.mkApp { inherit pkgs; cookiesDir = "./cookies"; script = ./task.ts; }`.
Copy `commands/keyfarm-maintain.md` into your `.claude/commands/` and write a
functional command (`templates/functional-command.md`).

## Design notes
- **Jail:** bubblewrap (fs/process isolation; network shared). Chromium `--no-sandbox`
  inside — bwrap is the sandbox.
- **Stealth:** patchright kills the automation tells. Browser is `pkgs.chromium`
  (overridable, but **never Google Chrome**).
- **Turnstile:** not LLM-solvable; the lever is a warm profile (`cf_clearance`,
  bound to IP+UA+TLS, ~30 min) + patchright + a good IP. Datacenter IPs still get hit.
- See `docs/superpowers/specs/2026-07-29-keyfarm-design.md`.
