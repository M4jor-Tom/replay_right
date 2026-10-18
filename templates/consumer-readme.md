# @NAME@

A keyfarm consumer. Functional command: `commands/@NAME@.md`.

- **Farm keys** (log in by hand): `nix run .#browser -- ./cookies`
- **Maintain the script** with AI: run the `keyfarm-maintain` command on `commands/@NAME@.md`
- **Replay** deterministically: `nix run .#default`

To use installed Firefox outside the jail, add `-- --browser firefox <profile-name>`
to either browser or replay command (omit `./cookies`). The named profile is required
and must be closed first; `privacy` is a profile name, not private-browsing mode.
