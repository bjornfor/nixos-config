{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../cfg/base-medium.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # TODO: patch nixos-generate-config to detect bcache, so this ends up in
  # hardware-configuration.nix automatically.
  boot.initrd.availableKernelModules = [ "bcache" ];

  networking.hostName = "media";

  system.autoUpgrade = {
    enable = false;  # too many issues with the desktop disappearing
    dates = "04:40";
    channel = "https://nixos.org/channels/nixos-18.03";
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
      options = "ro,credentials=/root/.credentials.maria-pc,uid=bfo,gid=users,iocharset=utf8";
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

  services.xserver.displayManager.gdm.autoLogin.user = lib.mkForce "media";
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

  users.extraUsers.bfo.openssh.authorizedKeys.keys = with import ../../misc/ssh-keys.nix; [
    mini.bfo.default
    whitetip.bfo.default
  ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "17.03";
}
