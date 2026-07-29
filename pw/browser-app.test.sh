#!/usr/bin/env bash
set -euo pipefail
DIR="$(mktemp -d)"
# Smoke: headless override so CI has no display; assert profile gets populated.
KEYFARM_SMOKE=1 timeout 30 nix run .#browser -- "$DIR" || true
test -d "$DIR/Default" && echo "PASS: profile created" || { echo "FAIL: no profile"; exit 1; }
