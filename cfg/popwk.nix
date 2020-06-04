# popwk - Power on/off (PJLINK) projector with (Logitech wireless) keyboard.

{ config, lib, pkgs, ... }:

let
  projectorIpAddr = "192.168.0.11";
in
{
  # This must be a system service so it works even at the login screen
  # (before any user services have started).
  systemd.services.popwk = {
    description = "Power on/off projector with keyboard";
    wantedBy = [ "multi-user.target" ];
    after = [ "dbus.service" "systemd-logind.service" ];
    path = with pkgs; [
      "/run/wrappers"  # for sudo
    ];
    serviceConfig = {
      ExecStart = "${pkgs.my.popwk}/bin/popwk ${projectorIpAddr}";

      # This service runs as root, with sandboxing for protection. (See the
      # SANDBOXING section in man systemd.exec.) Ideally it would run as
      # DynamicUser, but how to get desktop notifications to work then?
      # (`sudo -u $otheruser notify-desktop ...` requires access to
      # /run/user/).
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      InaccessiblePaths = [ "/root" "/home" ];
      PrivateTmp = true;
      NoNewPrivileges = true;
      DeviceAllow = "char-hidraw rw";
    };
  };
}
