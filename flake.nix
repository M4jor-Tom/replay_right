{
  description = "keyfarm — jailed stealth browser + AI-maintained Playwright scripts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        mkJailed = pkgs.callPackage ./nix/jail.nix { };
        keyfarm-chromium = mkJailed { browser = pkgs.chromium; };
        # test-only: a jail whose exe is `env`, so `.#jail-test -- cat FILE`
        # runs `env cat FILE` inside the jail and proves host files are hidden.
        jail-test = mkJailed { browser = pkgs.coreutils; name = "keyfarm-jail-test"; exe = "env"; };
        pw = pkgs.callPackage ./nix/pw.nix { };
        browser-app = pkgs.writeShellApplication {
          name = "keyfarm-browser";
          runtimeInputs = [ keyfarm-chromium pkgs.coreutils ];
          text = ''
            : "''${1:?usage: keyfarm-browser <cookies-dir>}"
            KEYFARM_PROFILE="$(realpath -m "$1")"
            export KEYFARM_PROFILE
            shift
            extra=()
            [ -n "''${KEYFARM_SMOKE:-}" ] && extra=(--headless=new --no-sandbox --disable-dev-shm-usage --dump-dom about:blank)
            exec keyfarm-chromium --user-data-dir="$KEYFARM_PROFILE" "''${extra[@]}" "$@"
          '';
        };
        run-app = pkgs.writeShellApplication {
          name = "keyfarm-run";
          runtimeInputs = [ pkgs.nodejs_22 keyfarm-chromium pkgs.coreutils ];
          text = ''
            : "''${1:?usage: keyfarm-run <cookies-dir> <script.ts>}" "''${2:?usage: keyfarm-run <cookies-dir> <script.ts>}"
            export KEYFARM_CHROMIUM="${keyfarm-chromium}/bin/keyfarm-chromium"
            KEYFARM_PROFILE="$(realpath -m "$1")"
            export KEYFARM_PROFILE
            exec node --import ${pw}/lib/node_modules/tsx/dist/loader.mjs ${pw}/lib/runner.ts "$@"
          '';
        };
      in {
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.nodejs_22 pkgs.chromium pkgs.bubblewrap ];
          shellHook = ''
            [ -d pw/node_modules ] || (cd pw && npm ci)
          '';
        };
        packages.keyfarm-chromium = keyfarm-chromium;
        packages.pw = pw;
        apps.jail-test = { type = "app"; program = "${jail-test}/bin/keyfarm-jail-test"; };
        apps.browser = { type = "app"; program = "${browser-app}/bin/keyfarm-browser"; };
        apps.run = { type = "app"; program = "${run-app}/bin/keyfarm-run"; };
      })
    // {
      lib.mkApp = { pkgs, cookiesDir, script, browser ? pkgs.chromium, headless ? true }:
        let
          mkJailed = pkgs.callPackage ./nix/jail.nix { };
          jailed = mkJailed { inherit browser; };
          pw = pkgs.callPackage ./nix/pw.nix { };
          app = pkgs.writeShellApplication {
            name = "keyfarm-app";
            runtimeInputs = [ pkgs.nodejs_22 jailed ];
            text = ''
              export KEYFARM_CHROMIUM="${jailed}/bin/keyfarm-chromium"
              export KEYFARM_PROFILE="${cookiesDir}"
              export KEYFARM_HEADLESS="${if headless then "1" else "0"}"
              exec node --import ${pw}/lib/node_modules/tsx/dist/loader.mjs ${pw}/lib/runner.ts "${cookiesDir}" "${script}"
            '';
          };
        in { type = "app"; program = "${app}/bin/keyfarm-app"; };
    };
}
