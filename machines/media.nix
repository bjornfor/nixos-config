{ config, lib, pkgs, ... }:

{
  imports = [
    ../config/base-medium.nix
  ];

  boot.loader.grub.device =
    "/dev/disk/by-id/ata-Corsair_Force_3_SSD_123479100000148001C8";

  fileSystems."/mnt/backup-disk" =
    { device = "/dev/disk/by-label/backup";
      options = [ "nofail" ];
    };

  networking.hostName = "media";

  system.autoUpgrade = {
    enable = true;
    dates = "04:40";
    channel = "https://nixos.org/channels/nixos-17.03";
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
        "audio"
        "cdrom"
        "dialout"
        "networkmanager"
        "plugdev"
        "scanner"
        "transmission"
        "video"
        "wheel"
      ];
      isNormalUser = true;
      initialPassword = "media";
    };
  };

  services.borg-backup = rec {
    enable = true;
    repository = "/mnt/backup-disk/backup-maria.borg";
    archiveBaseName = "maria-pc_seagate_expansion_drive_4tb";
    pathsToBackup = [ "/mnt/${archiveBaseName}" ];
    preHook = ''
      # access the mountpoint now, to trigger automount (why is this needed?)
      if ! ls -ld /mnt/${archiveBaseName}; then
          die "Failed to mount maria-pc"
      fi
      # Oops! autofs is considered a filesystem, so this check will always pass.
      if ! mountpoint /mnt/${archiveBaseName}; then
          die "exiting"
      fi
    '';
  };

  users.extraUsers.bfo.openssh.authorizedKeys.keys = with import ../misc/ssh-keys.nix; [
    bfo_at_mini
  ];
}
