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
VISUAL="$WORK/ed.sh" EDITOR="$WORK/ed.sh" timeout 180 nix run "$KEYFARM#spawn_consumer_repo" -- mysite
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
if VISUAL=true EDITOR=true timeout 120 nix run "$KEYFARM#spawn_consumer_repo" -- untouched; then
  echo "FAIL: expected non-zero exit on unchanged edit"; exit 1
fi
[ ! -e untouched ] || { echo "FAIL: repo created despite unchanged edit"; exit 1; }
echo "PASS case 2 (abort on unchanged)"

# --- Case 3: abort on existing dir ---
mkdir existing
if VISUAL=true EDITOR=true timeout 120 nix run "$KEYFARM#spawn_consumer_repo" -- existing; then
  echo "FAIL: expected refusal on existing dir"; exit 1
fi
echo "PASS case 3 (abort on existing)"
echo "ALL PASS"
