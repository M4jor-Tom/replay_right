{
  description = "keyfarm — jailed stealth browser + AI-maintained Playwright scripts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.nodejs_22 pkgs.chromium pkgs.bubblewrap ];
          shellHook = ''
            [ -d pw/node_modules ] || (cd pw && npm ci)
          '';
        };
      });
}
