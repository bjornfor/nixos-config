# NixOS module for running deCONZ ZigBee gateway as a service.
#
# FIXME: These two auth issues:
# https://github.com/dresden-elektronik/deconz-rest-plugin/issues/1788 ("Auth problems on non-80 http port")
# https://github.com/dresden-elektronik/deconz-rest-plugin/issues/1792 ("Trying to change password: "Service not available. Try again later.")

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.local.services.deconz;
  name = "deconz";
  stateDir = "/var/lib/${name}";
in
{
  options.local.services.deconz = {

    enable = mkEnableOption "deCONZ, a ZigBee gateway";

    package = mkOption {
      type = types.package;
      default = pkgs.deconz;
      defaultText = "pkgs.deconz";
      description = "Which deCONZ package to use.";
    };

    device = mkOption {
      type = types.str;
      default = "";
      description = ''
        Force deCONZ to use a specific USB device (e.g. /dev/ttyACM0). By
        default it does a search.
      '';
    };

    httpPort = mkOption {
      type = types.port;
      default = 80;
      description = "TCP port for the web server.";
    };

    wsPort = mkOption {
      type = types.port;
      default = 443;
      description = "TCP port for the WebSocket.";
    };

    openFirewall = mkEnableOption "open up the service ports in the firewall";

    allowRebootSystem = mkEnableOption "allow rebooting the system";

    allowRestartService = mkEnableOption "allow killing/restarting processes";

    allowSetSystemTime = mkEnableOption "allow setting the system time";

    extraOpts = mkOption {
      type = types.listOf types.str;
      default = [
        "--auto-connect=1"
        "--dbg-info=1"
      ];
      description = ''
        Extra command line options for deCONZ.
        These options seem undocumented, but some examples can be found here:
        https://github.com/marthoc/docker-deconz/blob/master/amd64/root/start.sh
      '';
    };
  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      cfg.httpPort
      cfg.wsPort
    ];

    systemd.services.deconz = {
      description = "deCONZ ZigBee gateway";
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        # The service puts a nix store path reference in here, and that path can
        # be garbage collected. Ensure the file gets "refreshed" on every start.
        rm -f ${stateDir}/.local/share/dresden-elektronik/deCONZ/zcldb.txt
      '';
      serviceConfig = {
        ExecStart =
          "${cfg.package}/bin/deCONZ"
          + " -platform minimal"
          + " --http-port=${toString cfg.httpPort}"
          + " --ws-port=${toString cfg.wsPort}"
          + (if cfg.device != "" then " --dev=${cfg.device}" else "")
          + " " + (lib.concatStringsSep " " cfg.extraOpts);
        Restart = "on-failure";
        AmbientCapabilities =
          let
            # ref. upstream deconz.service
            caps = lib.optionals (cfg.httpPort < 1024 || cfg.wsPort < 1024) [ "CAP_NET_BIND_SERVICE" ]
                ++ lib.optionals (cfg.allowRebootSystem) [ "CAP_SYS_BOOT" ]
                ++ lib.optionals (cfg.allowRestartService) [ "CAP_KILL" ]
                ++ lib.optionals (cfg.allowSetSystemTime) [ "CAP_SYS_TIME" ];
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
  };
}
