{ config, lib, pkgs, ... }:

{
  imports = [ ./xserver.nix ];

  services.xserver = {
    displayManager.sddm.enable = true;
    desktopManager.plasma5.enable = true;
  };

  environment.systemPackages = with pkgs; [
    kdeApplications.ark
    kdeApplications.gwenview
    kdeApplications.kmix
    kdeApplications.okular
  ];
}
