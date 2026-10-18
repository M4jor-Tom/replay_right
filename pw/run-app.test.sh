#!/usr/bin/env bash
set -euo pipefail
DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT
cat > "$DIR/task.ts" <<'EOF'
import { writeFileSync } from 'node:fs';
export async function run(page) {
  await page.setContent('<title>keyfarm-ok</title>');
  writeFileSync(process.env.KEYFARM_OUT, await page.title());
}
EOF
# Smoke: runs jailed Firefox end to end (KEYFARM_BROWSER is wired to the
# bwrap wrapper by run-app itself, not overridden here) via Node's TS loader.
KEYFARM_OUT="$DIR/out.txt" KEYFARM_HEADLESS=1 timeout 60 nix run .#run -- "$DIR" "$DIR/task.ts"
grep -q keyfarm-ok "$DIR/out.txt" && echo "PASS: run app drives jailed Firefox" || { echo "FAIL: no marker"; exit 1; }

# Only disposable profiles are used, never a personal Firefox profile.
mkdir -p "$DIR/home/.config/mozilla/firefox/privacy"
printf '[Profile0]\nName=privacy\nIsRelative=1\nPath=privacy\n' > "$DIR/home/.config/mozilla/firefox/profiles.ini"
export HOME="$DIR/home" XDG_CONFIG_HOME="$DIR/home/.config" KEYFARM_HEADLESS=1
export KEYFARM_OUT="$DIR/stock-out.txt"
timeout 60 nix run .#run -- --browser firefox privacy "$DIR/task.ts"
grep -q keyfarm-ok "$KEYFARM_OUT"
echo 'PASS: run app drives stock Firefox with a named profile'

export KEYFARM_TEST_SCRIPT="$DIR/task.ts"
app="$(nix build --no-link --print-out-paths --impure --expr '
  let f = builtins.getFlake (toString ./.);
      pkgs = f.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
      app = f.lib.mkApp { inherit pkgs; cookiesDir = "./unused-profile"; script = builtins.getEnv "KEYFARM_TEST_SCRIPT"; };
  in pkgs.runCommand "keyfarm-mkapp-test" {} "ln -s ${app.program} $out"
')"
export KEYFARM_OUT="$DIR/mkapp-out.txt"
(cd "$DIR" && timeout 60 "$app" --browser firefox privacy)
grep -q keyfarm-ok "$KEYFARM_OUT"
test ! -e "$DIR/unused-profile"
echo 'PASS: mkApp forwards the override without opening its default profile'
