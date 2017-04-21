# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
    [ ../config/base-small.nix

      # Build server
      ../config/hydra.nix

      # Monitoring
      ../options/collectd-graph-panel.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "hydra"; # Define your hostname.
  #networking.firewall.allowedTCPPorts = [ 3000 ];
  networking.firewall.enable = false;

  boot.tmpOnTmpfs = true;

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    vim
  ];

  services.lighttpd.enable = true;
  services.lighttpd.collectd-graph-panel.enable = true;

  services.collectd = {
    enable = true;
    extraConfig = ''
      # Interval at which to query values. Can be overwritten on per plugin
      # with the 'Interval' option.
      # WARNING: You should set this once and then never touch it again. If
      # you do, you will have to delete all your RRD files.
      Interval 10

      # Load plugins
      LoadPlugin apcups
      LoadPlugin contextswitch
      LoadPlugin cpu
      LoadPlugin df
      LoadPlugin disk
      LoadPlugin ethstat
      LoadPlugin interface
      LoadPlugin irq
      LoadPlugin load
      LoadPlugin memory
      LoadPlugin network
      LoadPlugin nfs
      LoadPlugin processes
      LoadPlugin rrdtool
      LoadPlugin sensors
      LoadPlugin tcpconns
      LoadPlugin uptime

      <Plugin "df">
        MountPoint "/"
      </Plugin>

      # Output/write plugin (need at least one, if metrics are to be persisted)
      <Plugin "rrdtool">
        CacheFlush 120
        WritesPerSecond 50
      </Plugin>
    '';
  };

  users.extraUsers.bfo.openssh.authorizedKeys.keys = with import ../misc/ssh-keys.nix; [
    bfo_at_whitetip
    bfo_at_mini
  ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "16.09";
}
