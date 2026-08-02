#!/usr/bin/env bash
set -euo pipefail
DIR="$(mktemp -d)"
# Smoke: headless flags passed through explicitly (no display in CI); assert profile gets populated.
timeout 90 nix run .#browser -- "$DIR" --headless=new --no-sandbox --disable-dev-shm-usage --dump-dom about:blank || true
test -d "$DIR/Default" && echo "PASS: profile created" || { echo "FAIL: no profile"; exit 1; }
