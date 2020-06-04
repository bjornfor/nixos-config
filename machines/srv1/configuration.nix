{ config, lib, pkgs, ... }:

let
  lan0 = "enp0s25";
in
{
  imports = [
    ./hardware-configuration.nix

    ./backup.nix
    ./ddclient.nix
    ./syncthing.nix

    ../../cfg/base-small.nix
    ../../cfg/bcache.nix
    ../../cfg/cgit.nix
    ../../cfg/git-daemon.nix
    ../../cfg/gitolite.nix
    ../../cfg/nix-remote-build-server.nix
    ../../cfg/postfix.nix
    ../../cfg/smart-daemon.nix
    ../../cfg/swraid.nix
    ../../cfg/transmission.nix
    ../../profiles/backup-server.nix
    ../../profiles/webserver.nix
    ../../users/bf.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # This machine has an old nvidia gfx card and "nomodeset" is needed to
  # prevent the display from going black / freeze in stage-2 boot.
  boot.kernelParams = [ "nomodeset" ];

  environment.systemPackages = with pkgs; [
    apacheHttpd  # for `htpasswd` (manage users/passwords for lighttpd)
    htop
    iotop
    ncdu
    nix-review
    python  # sshuttle needs python on the server side
    sysstat
    usbutils
  ];

  networking.hostName = "srv1";

  networking.firewall.allowedTCPPorts = [
    80    # web / http
    443   # web / https
    445   # samba
    9418  # git daemon
  ];

  # Add a bridge interface to be able to put libvirt/QEMU/KVM VMs directly on
  # the LAN.
  networking.bridges = {
    br0 = { interfaces = [ lan0 ]; };
  };
  # TODO: shouldn't have to turn off useDHCP just because dhcpcd doesn't enable
  # dhcp for bridges by default (that should be handled by the next line).
  # Ref. https://github.com/NixOS/nixpkgs/pull/82295
  networking.useDHCP = lib.mkForce false;
  networking.interfaces.br0.useDHCP = true;

  services.atd.enable = true;

  users.extraUsers.bf.openssh.authorizedKeys.keys = with config.local.resources.sshKeys; [
    mini.bf.default
    whitetip.bf.default
  ];

  virtualisation.libvirtd.enable = true;

  swapDevices = [
    { device = "/var/swap"; size = 32*1024; /* MiB */ }
  ];

  system.stateVersion = "19.03";
}
