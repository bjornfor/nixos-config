{ config, lib, pkgs, ... }:

{
  services = {
    xserver = {
      enable = true;
      layout = "no";
      displayManager.sddm.enable = true;
      desktopManager.lxqt.enable = true;
      libinput.enable = true;
    };
  };
}
