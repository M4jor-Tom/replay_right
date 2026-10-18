# keyfarm

Jailed, persistent Firefox + AI-maintained Playwright scripts, as a Nix flake.
The technical layer other (functional, website-specific) repos build on.

## Apps
- `nix run .#browser -- <cookies-dir>` — jailed **headful** Firefox for manual login; its profile persists in `<cookies-dir>`.
- `nix run .#run -- <cookies-dir> <script.ts>` — jailed **headless** Firefox replay of a `run(page)` script.
- `nix run .#spawn_consumer_repo -- <name>` — open the functional-command template in `$VISUAL`/`$EDITOR`; on close, scaffold `./<name>` as a keyfarm consumer repo (git-initialized). Override the keyfarm ref with `KEYFARM_REF=`.
- `nix develop` — Node 22, Playwright Core, the matching Playwright Firefox build, and bubblewrap.

## Installed Firefox and named profiles

To use your installed Firefox outside bubblewrap, put `--browser firefox <profile-name>` first:

```sh
nix run .#browser -- --browser firefox privacy https://example.com
nix run .#run -- --browser firefox privacy ./task.ts
# In a consumer created with lib.mkApp:
nix run .#default -- --browser firefox privacy
```

The profile name is required: `privacy` selects that named profile, **not** a private window.
Profiles are read from `$XDG_CONFIG_HOME/mozilla/firefox/profiles.ini` (default `~/.config`),
or `~/.mozilla/firefox/profiles.ini` if the former does not exist. Unknown profiles fail;
none are created. Close the selected profile before launching. The installed `firefox`
must be on `PATH`. The existing cookies directory is unused with this override.

Automation uses Playwright's experimental `moz-firefox` WebDriver BiDi channel,
keeping its generated preferences in a disposable directory rather than overwriting
your profile's `user.js`. Your normal cookies, settings and extensions remain in use;
normal browsing still updates the profile. The override removes filesystem isolation,
not website anti-bot restrictions. Without the option, the jailed browser is unchanged.

## Downstream use
Add keyfarm as a flake input and compose an app (see `templates/consumer-flake.nix`):
`keyfarm.lib.mkApp { inherit pkgs; cookiesDir = "./cookies"; script = ./task.ts; }`.
Copy `commands/keyfarm-maintain.md` into your `.claude/commands/` and write a
functional command (`templates/functional-command.md`).

## Design notes
- **Jail:** bubblewrap isolates filesystem/processes while sharing network. Firefox runs inside the same jail; its persistent profile is the only writable host path.
- **Browser:** Nixpkgs' `playwright-driver` supplies Playwright Core and its matching patched Firefox binary. The default driver uses the patched Firefox protocol; the explicit stock-Firefox override uses WebDriver BiDi instead.
- **Stealth:** Firefox is not stealth-patched. Use manual login and a warm profile; bot challenges may still occur. Turnstile is not solvable by clicking/vision, and no captcha-solving is included.
- Close the manual browser before running automation; Firefox locks a profile to one process at a time.

## Check

```sh
nix flake check
bash pw/browser-app.test.sh
bash pw/run-app.test.sh
# Real stock Firefox against localhost, using only a disposable profile:
nix develop --command node --experimental-strip-types --test pw/firefox.test.ts
```
