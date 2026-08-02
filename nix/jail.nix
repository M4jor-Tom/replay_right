{ bubblewrap, writeShellApplication, coreutils, lib }:

# mkJailed { browser } -> writeShellApplication `keyfarm-chromium`
{ browser, name ? "keyfarm-chromium", exe ? (lib.getExe browser) }:
writeShellApplication {
  inherit name;
  runtimeInputs = [ bubblewrap browser coreutils ];
  text = ''
    : "''${KEYFARM_PROFILE:?KEYFARM_PROFILE must be set to the profile dir}"
    mkdir -p "$KEYFARM_PROFILE"
    HOME_TMP="$(mktemp -d)"
    # keyfarm: display passthrough for headful farming (ro-bind-try/--setenv default
    # to empty/nonexistent so this is a no-op when no X11/Wayland display is present,
    # keeping the headless smoke test unaffected)
    xauth="''${XAUTHORITY:-/nonexistent}"
    wayland_sock="''${XDG_RUNTIME_DIR:-/nonexistent}/''${WAYLAND_DISPLAY:-nonexistent}"
    exec bwrap \
      --ro-bind /nix/store /nix/store \
      --ro-bind-try /etc/ssl /etc/ssl \
      --ro-bind-try /etc/static /etc/static \
      --ro-bind-try /etc/fonts /etc/fonts \
      --ro-bind-try /etc/resolv.conf /etc/resolv.conf \
      --ro-bind-try /run/current-system/sw/share/X11/fonts /run/current-system/sw/share/X11/fonts \
      --proc /proc --dev /dev \
      --tmpfs /tmp --tmpfs /dev/shm \
      --ro-bind-try /tmp/.X11-unix /tmp/.X11-unix \
      --bind "$KEYFARM_PROFILE" "$KEYFARM_PROFILE" \
      --bind "$HOME_TMP" "$HOME_TMP" --setenv HOME "$HOME_TMP" \
      --unshare-all --share-net --die-with-parent \
      --setenv DISPLAY "''${DISPLAY:-}" \
      --setenv WAYLAND_DISPLAY "''${WAYLAND_DISPLAY:-}" \
      --setenv XAUTHORITY "''${XAUTHORITY:-}" \
      --ro-bind-try "$xauth" "$xauth" \
      --ro-bind-try "$wayland_sock" "$wayland_sock" \
      -- ${exe} "$@"
  '';
}
