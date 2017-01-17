{ config, lib, pkgs, ... }:

{
  services = {
    xserver = {
      enable = true;
      layout = "no";
      displayManager.gdm.enable = true;
      displayManager.gdm.autoLogin.enable = true;
      displayManager.gdm.autoLogin.user = "bfo";
      desktopManager.gnome3.enable = true;
      libinput.enable = true;
    };
  };
}
