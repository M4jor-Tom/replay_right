#!/usr/bin/env bash
set -euo pipefail
DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT
mkdir -p "$DIR/home/.config/mozilla/firefox/privacy" "$DIR/bin"
printf '[Profile0]\nName=privacy\nIsRelative=1\nPath=privacy\n' > "$DIR/home/.config/mozilla/firefox/profiles.ini"
cat > "$DIR/bin/firefox" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$KEYFARM_OUT"
EOF
chmod +x "$DIR/bin/firefox"
export HOME="$DIR/home" XDG_CONFIG_HOME="$DIR/home/.config" KEYFARM_OUT="$DIR/args"
export PATH="$DIR/bin:$PATH"
nix run .#browser -- --browser firefox privacy about:blank
printf '%s\n' -no-remote -profile "$HOME/.config/mozilla/firefox/privacy" about:blank > "$DIR/expected"
cmp "$DIR/expected" "$KEYFARM_OUT"
rm "$KEYFARM_OUT"
for args in '--browser' '--browser firefox' '--browser chromium privacy' '--browser firefox missing'; do
  # Intentional splitting of this fixed list of invalid argv combinations.
  # shellcheck disable=SC2086
  if nix run .#browser -- $args; then echo "FAIL: accepted $args"; exit 1; fi
  test ! -e "$KEYFARM_OUT"
done
echo 'PASS: manual browser selects a named Firefox profile and rejects invalid overrides'
