#!/usr/bin/env bash
set -euo pipefail
DIR="$(mktemp -d)"
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
