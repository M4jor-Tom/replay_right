#!/usr/bin/env bash
# Proves the jail hides the host filesystem. Uses coreutils, not chromium.
set -euo pipefail
SENTINEL="$(mktemp)"; echo secret > "$SENTINEL"
PROFILE="$(mktemp -d)"
export KEYFARM_PROFILE="$PROFILE"
# mkJailed { browser = coreutils; } exposes bin/keyfarm-chromium = jailed `ls`-able env.
# We test the bwrap arg builder via `nix run .#jail-test -- cat "$SENTINEL"`.
if nix run .#jail-test -- cat "$SENTINEL" 2>/dev/null; then
  echo "FAIL: host file visible inside jail"; exit 1
else
  echo "PASS: host file hidden"; exit 0
fi
