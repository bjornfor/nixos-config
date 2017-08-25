{ config, lib, pkgs, ... }:

{
  services = {
    xserver = {
      enable = true;
      layout = "no";
      displayManager.sddm.enable = true;
      desktopManager.plasma5.enable = true;
      libinput.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    kdeApplications.ark
    kdeApplications.gwenview
    kdeApplications.okular
  ];
}
