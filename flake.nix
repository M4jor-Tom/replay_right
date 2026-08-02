{
  description = "keyfarm — jailed stealth browser + AI-maintained Playwright scripts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      runnerCmd = pw: "node --import ${pw}/lib/node_modules/tsx/dist/loader.mjs ${pw}/lib/runner.ts";
      toApp = drv: bin: { type = "app"; program = "${drv}/bin/${bin}"; };
      mkKeyfarmPkgs = pkgs: { mkJailed = pkgs.callPackage ./nix/jail.nix { }; pw = pkgs.callPackage ./nix/pw.nix { }; };
    in
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (mkKeyfarmPkgs pkgs) mkJailed pw;
        keyfarm-chromium = mkJailed { browser = pkgs.chromium; };
        # test-only: a jail whose exe is `env`, so `.#jail-test -- cat FILE`
        # runs `env cat FILE` inside the jail and proves host files are hidden.
        jail-test = mkJailed { browser = pkgs.coreutils; name = "keyfarm-jail-test"; exe = "env"; };
        browser-app = pkgs.writeShellApplication {
          name = "keyfarm-browser";
          runtimeInputs = [ keyfarm-chromium pkgs.coreutils ];
          text = ''
            : "''${1:?usage: keyfarm-browser <cookies-dir>}"
            KEYFARM_PROFILE="$(realpath -m "$1")"
            export KEYFARM_PROFILE
            shift
            exec keyfarm-chromium --user-data-dir="$KEYFARM_PROFILE" "$@"
          '';
        };
        run-app = pkgs.writeShellApplication {
          name = "keyfarm-run";
          runtimeInputs = [ pkgs.nodejs_22 keyfarm-chromium pkgs.coreutils ];
          text = ''
            : "''${1:?usage: keyfarm-run <cookies-dir> <script.ts>}" "''${2:?usage: keyfarm-run <cookies-dir> <script.ts>}"
            export KEYFARM_CHROMIUM="${keyfarm-chromium}/bin/keyfarm-chromium"
            exec ${runnerCmd pw} "$@"
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
        apps.jail-test = toApp jail-test "keyfarm-jail-test";
        apps.browser = toApp browser-app "keyfarm-browser";
        apps.run = toApp run-app "keyfarm-run";
      })
    // {
      lib.mkApp = { pkgs, cookiesDir, script, browser ? pkgs.chromium, headless ? true }:
        let
          inherit (mkKeyfarmPkgs pkgs) mkJailed pw;
          jailed = mkJailed { inherit browser; };
          app = pkgs.writeShellApplication {
            name = "keyfarm-app";
            runtimeInputs = [ pkgs.nodejs_22 jailed ];
            text = ''
              export KEYFARM_CHROMIUM="${jailed}/bin/keyfarm-chromium"
              export KEYFARM_HEADLESS="${if headless then "1" else "0"}"
              exec ${runnerCmd pw} "${cookiesDir}" "${script}"
            '';
          };
        in toApp app "keyfarm-app";
    };
}
