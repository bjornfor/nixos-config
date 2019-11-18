{ config, lib, pkgs, ... }:

{
  imports = [ ./xserver.nix ];

  services.xserver = {
    displayManager.gdm.enable = true;
    desktopManager.gnome3.enable = true;
  };

  environment.systemPackages = with pkgs; [
    # Extensions must be manually enabled in GNOME Tweaks (previously named
    # Tweak Tool). Adding them here only makes them available, but not active.
    gnomeExtensions.dash-to-dock
    gnomeExtensions.gsconnect
    gnomeExtensions.system-monitor

    gnome3.gnome-documents
    gnome3.gnome-nettool
    gnome3.gnome-power-manager
    gnome3.gnome-todo
    gnome3.gnome-tweaks
    gnome3.gnome-usage
  ] ++
  (with lib;
    # removed in nixos 20.03, it's part of GNOME3 now
    optional (versionOlder version "20.03")
    gnomeExtensions.nohotcorner
  );
}
