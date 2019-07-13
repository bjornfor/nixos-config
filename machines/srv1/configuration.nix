{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ./backup.nix
    ./ddclient.nix
    ./syncthing.nix
    ./webserver.nix

    ../../cfg/base-small.nix

    ../../cfg/backup-server.nix
    ../../cfg/bcache.nix
    ../../cfg/cgit.nix
    ../../cfg/git-daemon.nix
    ../../cfg/gitolite.nix
    ../../cfg/postfix.nix
    ../../cfg/smart-daemon.nix
    ../../cfg/swraid.nix
    ../../cfg/users-and-groups.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.tmpOnTmpfs = true;

  # This machine has an old nvidia gfx card and "nomodeset" is needed to
  # prevent the display from going black / freeze in stage-2 boot.
  boot.kernelParams = [ "nomodeset" ];

  networking.hostName = "srv1";

  networking.firewall.allowedTCPPorts = [
    80    # web / http
    443   # web / https
    445   # samba
    9418  # git daemon
  ];

  users.extraUsers.bf.openssh.authorizedKeys.keys = with import ../../misc/ssh-keys.nix; [
    mini.bf.default
    whitetip.bf.default
  ];

  virtualisation.libvirtd.enable = true;

  swapDevices = [
    { device = "/var/swap"; size = 32*1024; /* MiB */ }
  ];

  system.stateVersion = "19.03";
}
