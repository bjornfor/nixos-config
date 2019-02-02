{ config, lib, pkgs, ... }:

{
  imports = [ ./xserver.nix ];

  services.xserver = {
    displayManager.gdm.enable = true;
    displayManager.gdm.autoLogin.enable = true;
    displayManager.gdm.autoLogin.user = "bfo";
    desktopManager.gnome3.enable = true;
  };

  environment.systemPackages = with pkgs; [
    # Extensions must be manually enabled in GNOME Tweaks (previously named
    # Tweak Tool). Adding them here only makes them available, but not active.
    gnomeExtensions.dash-to-dock
    gnomeExtensions.system-monitor
  ];

}
