{ config, lib, pkgs, ... }:

{
  services = {
    munin-node.enable = true;
    munin-node.extraConfig = ''
      cidr_allow 192.168.1.0/24
    '';

    munin-cron = {
      enable = true;
      hosts = ''
        [${config.networking.hostName}]
        address localhost
      '';
    };
  };
}
