# spawn_consumer_repo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A keyfarm flake app `spawn_consumer_repo` that opens the functional-command template in `$EDITOR` and, on close, scaffolds a git-initialized repo (in `$PWD/<name>`) that consumes keyfarm.

**Architecture:** A single `writeShellApplication` in keyfarm's `flake.nix`. It bakes nix-store references to keyfarm's own template/command files, opens the editor on a pre-filled temp copy, aborts on an empty/unchanged edit, and otherwise `sed`/`cp`s a small set of files into `$PWD/<name>` and `git init`s it. Consumer files come from `templates/` (`@NAME@`/`@KEYFARM_REF@` tokens substituted via `sed`) — no templating engine.

**Tech Stack:** Nix flakes (`writeShellApplication`, shellcheck), POSIX shell, `sed`/`cp`/`git`/`coreutils`. Test is a bash script driving `nix run`.

## Global Constraints

- The app is a **single shell scaffolder** — `sed`/`cp`/heredoc only, no templating engine (YAGNI).
- **Naming:** use current `keyfarm` naming (`lib.mkApp`, `keyfarm-*`, `inputs.keyfarm` alias). The keyfarm→replay_right rename is a **separate migration** that must later sweep this app + its templates. Do NOT rename here.
- keyfarm flake ref default: **`github:M4jor-Tom/replay_right/develop`** (public; the flake lives on `develop`), overridable via the **`KEYFARM_REF`** env var.
- Target dir is **`$PWD/<name>`**; **abort (non-zero, no clobber) if it exists**; **abort if the edit is empty or byte-unchanged** from the pre-fill.
- The generated repo gets `git init` + one initial commit; consumer flake targets **`x86_64-linux`**, exposing `apps.default` (via `keyfarm.lib.mkApp`) and `apps.browser` (re-exported from keyfarm).
- **Flakes only see git-tracked files** — `git add` new/changed files before any `nix run`/`nix eval`.
- Conventional Commits; keyfarm's own commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure

- `flake.nix` — add `spawn-consumer-repo` (`writeShellApplication`) to the per-system `let`; add `apps.spawn_consumer_repo`.
- `templates/consumer-flake.nix` — MODIFY into a token template (`@NAME@`, `@KEYFARM_REF@`).
- `templates/consumer-readme.md` — CREATE (token template, `@NAME@`).
- `nix/spawn-consumer-repo.test.sh` — CREATE (happy-path offline + two abort cases).
- `README.md` — one line documenting the app.

---

## Task 1: spawn_consumer_repo scaffolder app

**Files:**
- Modify: `flake.nix` (add `spawn-consumer-repo` + `apps.spawn_consumer_repo`)
- Modify: `templates/consumer-flake.nix`
- Create: `templates/consumer-readme.md`
- Create: `nix/spawn-consumer-repo.test.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: keyfarm's existing `lib.mkApp`, `apps.browser`, `templates/functional-command.md` (has the literal `<what this automates>` title placeholder), `templates/task.ts`, `commands/keyfarm-maintain.md`, and the `toApp` helper in `flake.nix`.
- Produces: `apps.spawn_consumer_repo` → runnable as `nix run '<keyfarm>#spawn_consumer_repo' -- <name>`. Env: reads `KEYFARM_REF`, `VISUAL`/`EDITOR`.

- [ ] **Step 1: Write the failing test** — `nix/spawn-consumer-repo.test.sh`

```bash
#!/usr/bin/env bash
# Drives the spawn_consumer_repo app offline (KEYFARM_REF=path:<keyfarm>).
set -euo pipefail
KEYFARM="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
export KEYFARM_REF="path:$KEYFARM"

# --- Case 1: happy path (editor writes a line) ---
cat > ed.sh <<'EOF'
#!/usr/bin/env bash
printf '\n1. Open https://example.com\n' >> "$1"
EOF
chmod +x ed.sh
EDITOR="$WORK/ed.sh" timeout 180 nix run "$KEYFARM#spawn_consumer_repo" -- mysite
for f in flake.nix task.ts .gitignore README.md commands/mysite.md .claude/commands/keyfarm-maintain.md cookies/.gitkeep; do
  test -f "mysite/$f" || { echo "FAIL: missing mysite/$f"; exit 1; }
done
[ "$(git -C mysite rev-list --count HEAD)" = "1" ] || { echo "FAIL: expected 1 commit"; exit 1; }
grep -q "path:$KEYFARM" mysite/flake.nix || { echo "FAIL: KEYFARM_REF not injected"; exit 1; }
grep -q "mysite" mysite/README.md || { echo "FAIL: name not substituted in README"; exit 1; }
[ "$(timeout 200 nix eval --raw "$WORK/mysite#apps.x86_64-linux.default.type")" = "app" ] \
  || { echo "FAIL: generated flake does not eval to an app"; exit 1; }
echo "PASS case 1 (happy path)"

# --- Case 2: abort on unchanged edit (EDITOR=true touches nothing) ---
if EDITOR=true timeout 120 nix run "$KEYFARM#spawn_consumer_repo" -- untouched; then
  echo "FAIL: expected non-zero exit on unchanged edit"; exit 1
fi
[ ! -e untouched ] || { echo "FAIL: repo created despite unchanged edit"; exit 1; }
echo "PASS case 2 (abort on unchanged)"

# --- Case 3: abort on existing dir ---
mkdir existing
if timeout 120 nix run "$KEYFARM#spawn_consumer_repo" -- existing; then
  echo "FAIL: expected refusal on existing dir"; exit 1
fi
echo "PASS case 3 (abort on existing)"
echo "ALL PASS"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `chmod +x nix/spawn-consumer-repo.test.sh && git add -A && timeout 240 bash nix/spawn-consumer-repo.test.sh 2>&1 | tail -20`
Expected: FAIL — `nix run` errors that `spawn_consumer_repo` is not a valid app attribute. (`git add -A` first so the flake sees the new test/templates as you add them.)

- [ ] **Step 3: Rewrite `templates/consumer-flake.nix` as a token template**

```nix
{
  description = "@NAME@ — keyfarm consumer";
  inputs.keyfarm.url = "@KEYFARM_REF@";
  inputs.nixpkgs.follows = "keyfarm/nixpkgs";
  outputs = { self, keyfarm, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      apps.${system} = {
        default = keyfarm.lib.mkApp {
          inherit pkgs;
          cookiesDir = "./cookies";
          script = ./task.ts;
        };
        browser = keyfarm.apps.${system}.browser;
      };
    };
}
```
(This file is a template, not a directly-evaluated flake — `@KEYFARM_REF@` is fine; nothing in keyfarm's own `flake check` imports it.)

- [ ] **Step 4: Create `templates/consumer-readme.md`**

```markdown
# @NAME@

A keyfarm consumer. Functional command: `commands/@NAME@.md`.

- **Farm keys** (log in by hand): `nix run .#browser -- ./cookies`
- **Maintain the script** with AI: run the `keyfarm-maintain` command on `commands/@NAME@.md`
- **Replay** deterministically: `nix run .#default`
```

- [ ] **Step 5: Add the app to `flake.nix`**

In the per-system `let` (alongside `browser-app`/`run-app`), add:
```nix
        spawn-consumer-repo = pkgs.writeShellApplication {
          name = "keyfarm-spawn-consumer-repo";
          runtimeInputs = [ pkgs.coreutils pkgs.git pkgs.nano ];
          text = ''
            : "''${1:?usage: keyfarm-spawn-consumer-repo <name>}"
            name="$1"
            dir="$PWD/$name"
            if [ -e "$dir" ]; then echo "error: $dir already exists" >&2; exit 1; fi
            ref="''${KEYFARM_REF:-github:M4jor-Tom/replay_right/develop}"

            tmp="$(mktemp --suffix=.md)"
            trap 'rm -f "$tmp"' EXIT
            sed "s|<what this automates>|$name|" ${./templates/functional-command.md} > "$tmp"
            pristine="$(sha256sum < "$tmp")"

            # shellcheck disable=SC2086  # word-split is intentional (supports e.g. EDITOR="code --wait")
            ''${VISUAL:-''${EDITOR:-nano}} "$tmp"

            if [ ! -s "$tmp" ] || [ "$(sha256sum < "$tmp")" = "$pristine" ]; then
              echo "nothing written; no repo created" >&2
              exit 1
            fi

            mkdir -p "$dir/commands" "$dir/.claude/commands" "$dir/cookies"
            cp "$tmp" "$dir/commands/$name.md"
            cp ${./commands/keyfarm-maintain.md} "$dir/.claude/commands/keyfarm-maintain.md"
            cp ${./templates/task.ts} "$dir/task.ts"
            touch "$dir/cookies/.gitkeep"
            sed -e "s|@NAME@|$name|g" -e "s|@KEYFARM_REF@|$ref|g" ${./templates/consumer-flake.nix} > "$dir/flake.nix"
            sed -e "s|@NAME@|$name|g" ${./templates/consumer-readme.md} > "$dir/README.md"
            cat > "$dir/.gitignore" <<'EOF'
            result
            result-*
            cookies/*
            !cookies/.gitkeep
            .direnv/
            EOF

            git -C "$dir" init -q
            git -C "$dir" add -A
            git -C "$dir" commit -q -m "chore: scaffold $name — keyfarm consumer

            Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"

            echo "created $dir"
            echo "next: cd $name && nix run .#browser -- ./cookies   # farm keys (log in by hand)"
          '';
        };
```
In the returned attrset (next to the other `apps.*`):
```nix
        apps.spawn_consumer_repo = toApp spawn-consumer-repo "keyfarm-spawn-consumer-repo";
```
Notes for the implementer:
- `${./templates/...}` / `${./commands/...}` are **nix** interpolations (bake store paths) — do NOT escape them. `''${VAR}` is an **escaped shell** `${VAR}`.
- The `.gitignore` heredoc body is indented to match the nix `''` block; `writeShellApplication` runs the script through `bash`, but the heredoc delimiter `EOF` must be at column-0 of the emitted script OR use `<<-'EOF'` with tab indents. Simplest: keep the heredoc lines and `EOF` **unindented** inside the `''` string, or switch to writing `.gitignore` with `printf '%s\n' result 'result-*' 'cookies/*' '!cookies/.gitkeep' .direnv/ > "$dir/.gitignore"` to avoid heredoc-indentation pitfalls. Prefer the `printf` form if the heredoc fights the nix indentation.
- If `shellcheck` (run by `writeShellApplication`) flags anything beyond the disabled SC2086, fix minimally (this is the one calibration point).

- [ ] **Step 6: Stage everything (flakes see only tracked files)**

Run: `git add -A`
(Then the flake can resolve `${./templates/consumer-readme.md}` etc.)

- [ ] **Step 7: Run the test to verify it passes**

Run: `timeout 300 bash nix/spawn-consumer-repo.test.sh 2>&1 | tail -20`
Expected: `PASS case 1` / `PASS case 2` / `PASS case 3` / `ALL PASS`.
(If case 1's `nix eval` needs the store to build nixpkgs closure, it's cached from keyfarm; keep the timeout generous.)

- [ ] **Step 8: Document the app in `README.md`**

Add under the Apps list:
```markdown
- `nix run .#spawn_consumer_repo -- <name>` — open the functional-command template in `$EDITOR`; on close, scaffold `./<name>` as a keyfarm consumer repo (git-initialized). Override the keyfarm ref with `KEYFARM_REF=`.
```

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: spawn_consumer_repo app scaffolds a keyfarm consumer repo

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- §3 app (writeShellApplication, baked template refs, invocation) → Task 1 Step 5. ✓
- §4 flow (require name, abort-if-exists, prefill+title sub, editor blocks, abort-empty/unchanged, scaffold, git init+commit, next-steps) → Step 5 (app) + Steps 3–4 (templates). ✓
- §5 keyfarm ref (default github:M4jor-Tom/replay_right/develop, KEYFARM_REF override) → Step 5 (`ref=` line) + test injects `path:` override. ✓
- §6 generated layout (flake.nix, task.ts, commands/<name>.md, .claude/commands/keyfarm-maintain.md, cookies/.gitkeep, .gitignore, README.md) → Step 5 + test Case 1 asserts all. ✓
- §7 edge cases (missing arg, existing dir, empty/unchanged, no partial repo) → Step 5 guards + test Cases 2/3. ✓
- §8 testing (happy offline via KEYFARM_REF=path, abort-unchanged, abort-existing) → Step 1 test, three cases. ✓
- §9 files changed (flake.nix, templates, test, README) → all in Task 1. ✓
- Naming note (keep keyfarm naming) → Global Constraints. ✓

**Placeholder scan:** `@NAME@`/`@KEYFARM_REF@`/`<what this automates>`/`<name>` are intentional substitution tokens, not plan gaps. The one "calibration" (shellcheck / heredoc-indentation) is a concrete instruction with a `printf` fallback, not a TBD. No `TODO`/uncoded steps.

**Type consistency:** the app attr is `apps.spawn_consumer_repo` and the wrapper bin is `keyfarm-spawn-consumer-repo` consistently across Step 5, the test (`nix run "$KEYFARM#spawn_consumer_repo"`), and the README. `KEYFARM_REF` env name matches spec §5 and the test. Template tokens `@NAME@`/`@KEYFARM_REF@` are written in Steps 3–4 and substituted in Step 5 identically.
