{ config, lib, pkgs, ... }:

{
  local.services.deconz = {
    enable = true;
    httpPort = 1080;
    #httpPort = 80; # trying to work around https://github.com/dresden-elektronik/deconz-rest-plugin/issues/1788 ("Auth problems on non-80 http port")
    wsPort = 1443;
    openFirewall = true;
  };
}
