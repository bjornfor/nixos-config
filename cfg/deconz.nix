# NixOS module for running deCONZ ZigBee gateway as a service.
#
# FIXME: These two auth issues:
# https://github.com/dresden-elektronik/deconz-rest-plugin/issues/1788 ("Auth problems on non-80 http port")
# https://github.com/dresden-elektronik/deconz-rest-plugin/issues/1792 ("Trying to change password: "Service not available. Try again later.")

{ config, lib, pkgs, ... }:

let
  # options
  httpPort = 1080;
  #httpPort = 80; # trying to work around #1788 (see above)
  wsPort = 1443;
  openFirewall = true;
  allowRebootSystem = false;
  allowRestartService = false;
  allowSetSystemTime = false;

  # Settings from
  # https://github.com/marthoc/docker-deconz/blob/master/amd64/root/start.sh
  # (these do not seem documented anywhere).
  deconzOpts = [
    "--auto-connect=1"
    "--dbg-info=1"
    #"--dbg-aps=0"
    #"--dbg-zcl=0"
    #"--dbg-zdp=0"
    #"--dbg-otau=0"
    "--ws-port=${toString wsPort}"
    "--http-port=${toString httpPort}"
  ];

  name = "deconz";
  stateDir = "/var/lib/${name}";
in
{
  networking.firewall.allowedTCPPorts = lib.mkIf openFirewall [
    httpPort
    wsPort
  ];

  systemd.services.deconz = {
    description = "ZigBee gateway";
    wantedBy = [ "multi-user.target" ];

    # The app requires some GUI plugins, even when running headless
    # (-platform minimal). The Qt wrapper in NixOS 19.09 makes this setting
    # unneeded. Keep for backwards compat with 19.03.
    environment = with pkgs; if lib.versionOlder lib.version "19.09" then {
      QT_QPA_PLATFORM_PLUGIN_PATH = with pkgs.qt5;
          "${qtbase.bin}/lib/qt-${qtbase.qtCompatVersion}/plugins/platforms";
    } else {};

    preStart = ''
      # The service puts a nix store path reference in here, and that path can
      # be garbage collected. Ensure the file gets "refreshed" on every start.
      rm -f ${stateDir}/.local/share/dresden-elektronik/deCONZ/zcldb.txt
    '';
    serviceConfig = {
      ExecStart = "${pkgs.deconz}/bin/deCONZ -platform minimal " + lib.concatStringsSep " " deconzOpts;
      Restart = "on-failure";
      AmbientCapabilities =
        let
          # ref. upstream deconz.service
          caps = lib.optionals (httpPort < 1024) [ "CAP_NET_BIND_SERVICE" ]
              ++ lib.optionals (allowRebootSystem) [ "CAP_SYS_BOOT" ]
              ++ lib.optionals (allowRestartService) [ "CAP_KILL" ]
              ++ lib.optionals (allowSetSystemTime) [ "CAP_SYS_TIME" ];
        in
          lib.concatStringsSep " " caps;
      UMask = "0027";
      User = name;
      StateDirectory = name;
      WorkingDirectory = stateDir;

      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = "/tmp";
    };
  };

  users.users.deconz = {
    group = name;
    isSystemUser = true;
    home = stateDir;
    extraGroups = [ "dialout" ];  # for access to /dev/ttyACM0 (ConBee)
  };

  users.groups.deconz = {};
}
