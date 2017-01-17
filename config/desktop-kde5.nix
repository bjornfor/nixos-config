{ config, lib, pkgs, ... }:

{
  services = {
    xserver = {
      enable = true;
      layout = "no";
      displayManager.kdm.enable = true;
      desktopManager.kde5.enable = true;
      libinput.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    kde5.ark
    kde5.gwenview
    kde5.okular
  ];
}
