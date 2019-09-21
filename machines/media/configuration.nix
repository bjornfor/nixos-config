{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../cfg/base-medium.nix
    ../../cfg/disable-suspend.nix
    ../../cfg/bcache.nix
    ../../cfg/nix-remote-build-client.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "media";

  networking.firewall.allowedTCPPorts = [
    8081 # kodi web ui / remote control
    9090 # kodi web ui / remote control
  ];

  system.autoUpgrade = {
    enable = false;  # too many issues with the desktop disappearing
    dates = "04:40";
    channel = "https://nixos.org/channels/nixos-19.03";
  };

  nixpkgs.config = {
    # Disabled because it fails to build.
    # See https://github.com/NixOS/nixpkgs/issues/22333
    #chromium.enableWideVine = true;  # for Netflix, requires full chromium build
  };

  systemd.automounts = [
    { where = "/mnt/maria-pc_seagate_expansion_drive_4tb";
      wantedBy = [ "multi-user.target" ];
    }
  ];

  systemd.mounts = [
    { what = "//maria-pc/seagate_expansion_drive_4tb";
      where = "/mnt/maria-pc_seagate_expansion_drive_4tb";
      type = "cifs";
      options = "ro,credentials=/root/.credentials.maria-pc,uid=bf,gid=users,iocharset=utf8";
    }
  ];

  environment.systemPackages = with pkgs; [
    google-chrome
    kodi
    spotify
    transmission_gtk
  ];

  services.samba.enable = true; # required for nsswins to work
  services.samba.nsswins = true;

  services.xserver.displayManager.gdm.autoLogin.enable = true;
  services.xserver.displayManager.gdm.autoLogin.user = "media";
  virtualisation.libvirtd.enable = lib.mkForce false;

  users.extraUsers = {
    media = {
      description = "Media user";
      uid = 1001;
      extraGroups = [
        "cdrom"
        "transmission"
        "wheel"
      ];
      isNormalUser = true;
      initialPassword = "media";
    };
  };

  users.extraUsers.bf.openssh.authorizedKeys.keys = with import ../../misc/ssh-keys.nix; [
    mini.bf.default
    whitetip.bf.default
  ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "17.03";
}
