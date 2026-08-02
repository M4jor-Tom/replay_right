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
        spawn-consumer-repo = pkgs.writeShellApplication {
          name = "keyfarm-spawn-consumer-repo";
          runtimeInputs = [ pkgs.coreutils pkgs.gnused pkgs.git pkgs.nano ];
          text = ''
            : "''${1:?usage: keyfarm-spawn-consumer-repo <name>}"
            name="$1"
            dir="$PWD/$name"
            if [ -e "$dir" ]; then echo "error: $dir already exists" >&2; exit 1; fi
            ref="''${KEYFARM_REF:-github:M4jor-Tom/replay_right/develop}"

            tmp="$(mktemp --suffix=.md)"
            trap 'rm -f "$tmp"' EXIT
            sed "s|<what this automates>|$name|" ${./templates/functional-command.md} > "$tmp"
            pristine="$(sha256sum < "$tmp")"

            # shellcheck disable=SC2086  # word-split is intentional (supports e.g. EDITOR="code --wait")
            ''${VISUAL:-''${EDITOR:-nano}} "$tmp"

            if [ ! -s "$tmp" ] || [ "$(sha256sum < "$tmp")" = "$pristine" ]; then echo "nothing written; no repo created" >&2; exit 1; fi

            mkdir -p "$dir/commands" "$dir/.claude/commands" "$dir/cookies"
            cp "$tmp" "$dir/commands/$name.md"
            cp ${./commands/keyfarm-maintain.md} "$dir/.claude/commands/keyfarm-maintain.md"
            cp ${./templates/task.ts} "$dir/task.ts"
            touch "$dir/cookies/.gitkeep"
            sed -e "s|@NAME@|$name|g" -e "s|@KEYFARM_REF@|$ref|g" ${./templates/consumer-flake.nix} > "$dir/flake.nix"
            sed -e "s|@NAME@|$name|g" ${./templates/consumer-readme.md} > "$dir/README.md"
            printf '%s\n' result 'result-*' 'cookies/*' '!cookies/.gitkeep' .direnv/ > "$dir/.gitignore"

            git -C "$dir" init -q
            git -C "$dir" add -A
            git -C "$dir" commit -q -m "chore: scaffold $name — keyfarm consumer"

            echo "created $dir"
            echo "next: cd $name && nix run .#browser -- ./cookies   # farm keys (log in by hand)"
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
        apps.spawn_consumer_repo = toApp spawn-consumer-repo "keyfarm-spawn-consumer-repo";
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
