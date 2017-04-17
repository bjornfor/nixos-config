{ config, lib, pkgs, ... }:

{
  services = {
    munin-node.enable = true;

    munin-cron = {
      enable = true;
      hosts = ''
        [${config.networking.hostName}]
        address localhost
      '';
    };
  };
}
