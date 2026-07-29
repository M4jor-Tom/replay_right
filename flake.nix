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
      });
}
