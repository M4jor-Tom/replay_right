{
  inputs.keyfarm.url = "github:you/keyfarm";
  inputs.nixpkgs.follows = "keyfarm/nixpkgs";
  outputs = { self, keyfarm, nixpkgs }:
    let system = "x86_64-linux";
        pkgs = nixpkgs.legacyPackages.${system};
    in {
      apps.${system} = {
        default = keyfarm.lib.mkApp {
          inherit pkgs;
          cookiesDir = "./cookies";
          script = ./task.ts;
        };
        # re-export keyfarm's browser app so `nix run .#browser` resolves downstream
        browser = keyfarm.apps.${system}.browser;
      };
    };
}
