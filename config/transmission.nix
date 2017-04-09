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

}
