{ config, lib, pkgs, ... }:

let
  ports = { from = 1714; to = 1764; };
  kdeConnectImpl =
    if config.services.xserver.desktopManager.gnome3.enable then
      pkgs.gnomeExtensions.gsconnect
    else if config.services.xserver.desktopManager.plasma5.enable then
      pkgs.kdeconnect
    else
      throw "Don't know which KDE Connect implementation to use for this desktop";
in
{
  environment.systemPackages = [ kdeConnectImpl ];

  networking.firewall = {
    allowedTCPPortRanges = [ ports ];
    allowedUDPPortRanges = [ ports ];
  };
}
