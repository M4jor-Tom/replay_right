#!/usr/bin/env bash
set -euo pipefail
# Evaluate that lib.mkApp produces an app for a sample browser+script.
nix eval --impure --expr '
  let f = builtins.getFlake (toString ./.);
      pkgs = f.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  in (f.lib.mkApp { inherit pkgs; cookiesDir = "/tmp/x"; script = ./templates/task.ts; }).type
' | grep -q app && echo "PASS: mkApp yields an app" || { echo FAIL; exit 1; }
