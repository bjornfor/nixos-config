{ config, lib, pkgs, ... }:

{

  services.transmission = {
    enable = true;
    settings = {
      download-dir = "/srv/torrents/";
      incomplete-dir = "/srv/torrents/.incomplete/";
      incomplete-dir-enabled = true;
      rpc-whitelist = "127.0.0.1,192.168.1.*";
      ratio-limit = 2;
      ratio-limit-enabled = true;
      rpc-bind-address = "0.0.0.0";  # web server
    };
  };

  # Creating /srv/torrents requires root privileges. The transmission service
  # itself runs as unprivileged user. Use this helper service to create the
  # needed directories.
  systemd.services.transmission-setup-srv-torrents = {
    description = "Create /srv/torrents Directory For Transmission";
    requiredBy = [ "transmission.service" ];
    before = [ "transmission.service" ];
    script = ''
      mkdir -p /srv/torrents
      chown transmission:transmission /srv/torrents
    '';
    serviceConfig.Type = "oneshot";
  };

}
