{ bubblewrap, writeShellApplication, coreutils }:

# mkJailed { browser } -> writeShellApplication `keyfarm-chromium`
{ browser, name ? "keyfarm-chromium", exe ? "chromium" }:
writeShellApplication {
  inherit name;
  runtimeInputs = [ bubblewrap browser coreutils ];
  text = ''
    : "''${KEYFARM_PROFILE:?KEYFARM_PROFILE must be set to the profile dir}"
    mkdir -p "$KEYFARM_PROFILE"
    HOME_TMP="$(mktemp -d)"
    exec bwrap \
      --ro-bind /nix/store /nix/store \
      --ro-bind-try /etc/ssl /etc/ssl \
      --ro-bind-try /etc/static /etc/static \
      --ro-bind-try /etc/fonts /etc/fonts \
      --ro-bind-try /etc/resolv.conf /etc/resolv.conf \
      --ro-bind-try /run/current-system/sw/share/X11/fonts /run/current-system/sw/share/X11/fonts \
      --proc /proc --dev /dev \
      --tmpfs /tmp --tmpfs /dev/shm \
      --bind "$KEYFARM_PROFILE" "$KEYFARM_PROFILE" \
      --bind "$HOME_TMP" "$HOME_TMP" --setenv HOME "$HOME_TMP" \
      --unshare-all --share-net --die-with-parent \
      -- ${exe} "$@"
  '';
}
