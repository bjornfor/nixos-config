{ config, lib, pkgs, ... }:

{
  imports = [ ./xserver.nix ];

  services.xserver = {
    displayManager.sddm.enable = true;
    desktopManager.lxqt.enable = true;
  };
}
