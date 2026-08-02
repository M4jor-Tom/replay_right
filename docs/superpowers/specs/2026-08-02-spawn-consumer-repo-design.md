# spawn_consumer_repo — Design Spec

**Date:** 2026-08-02
**Status:** Approved for implementation planning
**Depends on:** keyfarm core (`docs/superpowers/specs/2026-07-29-keyfarm-design.md`)

## Naming note (pending migration)
The project will be renamed **keyfarm → replay_right** in a *separate* migration.
This spec and app deliberately use the **current** `keyfarm` naming
(`lib.mkApp`, `keyfarm-*` apps/wrappers, the `inputs.keyfarm` alias). The rename
migration MUST also sweep this app and the files it generates. The GitHub repo is
already `M4jor-Tom/replay_right` (public); only the local/attr naming lags.

## 1. Purpose
A keyfarm flake app that scaffolds a new **consumer repo** from a functional
command the user writes in their editor. Running it opens the pre-filled
functional-command template in `$EDITOR`; on close, a ready-to-use repo that
consumes keyfarm appears in the current directory.

## 2. Goals / Non-goals
**Goals**
- One command produces a working keyfarm consumer repo: `nix run '<keyfarm>#spawn_consumer_repo' -- <name>`.
- The functional command is authored interactively (editor), pre-filled from `templates/functional-command.md`.
- The generated repo consumes keyfarm via a GitHub flake input and is a git repo with an initial commit.

**Non-goals (YAGNI)**
- No templating engine — plain `cp` + a couple of `sed`/heredoc substitutions in a shell script.
- No interactive prompts beyond the editor (name comes from argv).
- No multi-system generation — the consumer flake targets `x86_64-linux`.
- No overwrite/merge of an existing target dir — abort instead.
- Does NOT perform the keyfarm→replay_right rename.

## 3. The app
`apps.spawn_consumer_repo` in keyfarm's `flake.nix` — a `writeShellApplication`
named `keyfarm-spawn-consumer-repo`. `runtimeInputs = [ coreutils git nano ]`
(nano only as the editor fallback). At build time it bakes nix-store references to
keyfarm's own files (so it is self-contained):
- `${./templates/functional-command.md}` — editor pre-fill source
- `${./templates/task.ts}` — scaffold script
- `${./commands/keyfarm-maintain.md}` — copied into the consumer

Invoke from the directory where you want the repo:
`nix run '/home/theta/repos/keyfarm#spawn_consumer_repo' -- <name>` or
`nix run 'github:M4jor-Tom/replay_right/develop#spawn_consumer_repo' -- <name>`.

## 4. Flow
1. Require exactly one arg `<name>`. Target `dir="$PWD/<name>"`. **Abort if `$dir` exists.**
2. Copy the functional-command pre-fill to a temp file `tmp`, substituting its
   title placeholder (`<what this automates>`) with `<name>`. Record `sha256sum` of `tmp`.
3. Open the editor: `"${VISUAL:-${EDITOR:-nano}}" "$tmp"`. This **blocks** until the
   editor exits (terminal editors do so naturally; GUI editors need their wait flag —
   documented caveat, e.g. `EDITOR='code --wait'`).
4. On close: if `tmp` is empty **or** its `sha256sum` is unchanged from the pristine
   pre-fill → **abort** ("nothing written; no repo created"), remove `tmp`, exit non-zero.
5. Else scaffold `$dir`:
   - `flake.nix` — generated via heredoc: `inputs.keyfarm.url = "${KEYFARM_REF:-github:M4jor-Tom/replay_right/develop}"`,
     `inputs.nixpkgs.follows = "keyfarm/nixpkgs"`, `system = "x86_64-linux"`,
     `apps.${system}.default = keyfarm.lib.mkApp { inherit pkgs; cookiesDir = "./cookies"; script = ./task.ts; }`,
     `apps.${system}.browser = keyfarm.apps.${system}.browser;`
   - `commands/<name>.md` — the edited functional command (move `tmp` here).
   - `.claude/commands/keyfarm-maintain.md` — copied from the baked store path.
   - `task.ts` — copied from the baked `templates/task.ts`.
   - `.gitignore` — `cookies/`, `result`, `result-*`, `.direnv/`; plus `cookies/.gitkeep`.
   - `README.md` — short: farm keys (`nix run .#browser -- ./cookies`), maintain
     (`/keyfarm-maintain commands/<name>.md`), replay (`nix run .#default`).
6. `git -C "$dir" init`; add all; initial commit
   `chore: scaffold <name> — keyfarm consumer` (with the Co-Authored-By trailer).
7. Print success + next-steps (cd, farm, maintain, run).

## 5. keyfarm ref
Default `github:M4jor-Tom/replay_right/develop` (public repo; the flake lives on
`develop`, not `main`). Overridable via the **`KEYFARM_REF`** env var — used both
for pinning and for offline testing (`KEYFARM_REF=path:/home/theta/repos/keyfarm`).

## 6. Generated repo layout
```
<name>/
  flake.nix                        # consumes keyfarm; apps.default (mkApp) + apps.browser
  task.ts                          # AI-maintained run(page) scaffold
  commands/<name>.md               # the functional command you wrote
  .claude/commands/keyfarm-maintain.md   # the harness (copied from keyfarm)
  cookies/.gitkeep                 # profile dir (contents gitignored)
  .gitignore
  README.md
```

## 7. Edge cases / error handling
- Missing `<name>` arg → usage message, exit non-zero.
- `$dir` exists → abort, exit non-zero (no clobber).
- Empty or unchanged edit → abort, remove temp, exit non-zero.
- Editor exits non-zero → abort, keep no partial repo.
- All scaffolding happens only AFTER a successful, changed edit, so an abort never
  leaves a half-made repo.

## 8. Testing
- **Happy path (offline):** run the app with `EDITOR` set to a tiny script that
  appends a line to the passed file, `KEYFARM_REF=path:/home/theta/repos/keyfarm`,
  from a temp CWD. Assert `<name>/{flake.nix,task.ts,commands/<name>.md,.claude/commands/keyfarm-maintain.md,.gitignore,README.md}` exist,
  `git -C <name> log --oneline` shows exactly one commit, and
  `nix flake check <name>` (or `nix eval <name>#apps.x86_64-linux.default.type`) evaluates
  to `app` with the local keyfarm input.
- **Abort — unchanged:** `EDITOR=true` (leaves the pre-fill untouched) ⇒ assert `<name>` was NOT created and exit code is non-zero.
- **Abort — existing dir:** pre-create `<name>` ⇒ assert the app refuses and exits non-zero without touching it.

## 9. Files changed in keyfarm
- `flake.nix` — add the `spawn-consumer-repo` `writeShellApplication` to the
  per-system `let`, and `apps.spawn_consumer_repo = toApp spawn-consumer-repo "keyfarm-spawn-consumer-repo";`.
- `pw/` or `nix/` — no changes.
- `templates/functional-command.md` — ensure it has a title placeholder the app substitutes (`<what this automates>`), else leave as-is.
- New test: `nix/spawn-consumer-repo.test.sh` (the three cases in §8).
- `README.md` — one line documenting the new app.
