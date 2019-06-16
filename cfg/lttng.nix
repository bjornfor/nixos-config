{ config, lib, pkgs, ... }:

{
  boot.extraModulePackages = with config.boot.kernelPackages; [
    lttng-modules
  ];

  environment.systemPackages = with pkgs; [
    babeltrace
    lttng-tools
  ];

  systemd.services.lttng-sessiond = {
    description = "LTTng Session Daemon";
    wantedBy = [ "multi-user.target" ];
    environment.MODULE_DIR = "/run/current-system/kernel-modules/lib/modules";
    serviceConfig = {
      ExecStart = "${pkgs.lttngTools}/bin/lttng-sessiond";
    };
  };
}
