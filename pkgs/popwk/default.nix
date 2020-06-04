{ stdenv, shellcheck
, ltunify, mawk, notify-desktop, systemd, jq, coreutils, dbus, libressl
}:

stdenv.mkDerivation rec {
  name = "popwk-${version}";
  version = "0";

  # building is only a few sed operations on a shell script
  preferLocalBuild = true;

  buildCommand = ''
    mkdir -p "$out/bin"
    dest="$out/bin/popwk"
    cp "${./popwk.sh}" "$dest"
    ${shellcheck}/bin/shellcheck "$dest"
    chmod +x "$dest"
    patchShebangs "$dest"

    # SUDO_BIN= is deliberately not fixed to an absolute path, because
    # the correct path depends on the operating system: NixOS uses
    # /run/wrappers/bin/sudo, but nobody else does. So rely on PATH
    # lookup for that one.
    sed -e "s|^LTUNIFY_BIN=.*|LTUNIFY_BIN=${ltunify}/bin/ltunify|" \
        -e "s|^MAWK_BIN=.*|MAWK_BIN=${mawk}/bin/mawk|" \
        -e "s|^NOTIFY_DESKTOP_BIN=.*|NOTIFY_DESKTOP_BIN=${notify-desktop}/bin/notify-desktop|" \
        -e "s|^LOGINCTL_BIN=.*|LOGINCTL_BIN=${systemd}/bin/loginctl|" \
        -e "s|^JQ_BIN=.*|JQ_BIN=${jq}/bin/jq|" \
        -e "s|^WC_BIN=.*|WC_BIN=${coreutils}/bin/wc|" \
        -e "s|^DBUS_SEND_BIN=.*|DBUS_SEND_BIN=${dbus}/bin/dbus-send|" \
        -e "s|^NC_BIN=.*|NC_BIN=${libressl.nc}/bin/nc|" \
        -i "$dest"
  '';

  meta = {
    description = "Power on/off projector with keyboard";
  };
}
