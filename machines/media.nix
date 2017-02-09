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
    channel = "https://nixos.org/channels/nixos-16.09";
  };

  nix.gc.automatic = true;
  nix.gc.dates = "03:15";
  nix.gc.options = "--delete-older-than 14d";

  nixpkgs.config = {
    chromium.enableWideVine = true;  # for Netflix, requires full chromium build
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
    firefox
    google-chrome
    kodi
    spotify
    transmission_gtk
    vlc
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

  systemd.services.borg-backup = {
    # Restore everything:
    # $ cd /mnt/restore
    # $ [sudo] borg extract --list /mnt/backup-disk/repo-name::archive-name
    #
    # Interactive restore (slower than 'borg extract'):
    # $ borg mount /mnt/backup-disk/repo-name /mnt/fuse-mountpoint
    # $ ls -1 /mnt/fuse-mountpoint
    # my-machine-20150220T234453
    # my-machine-20150321T114708
    # ... restore files (cp/rsync) ...
    # $ fusermount -u /mnt/fuse-mountpoint
    enable = true;
    description = "Borg Backup Service";
    startAt = "*-*-* 01:15:00";  # see systemd.time(7)
    environment = {
      BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes";
    };
    path = with pkgs; [
      borgbackup utillinux coreutils
    ];
    serviceConfig.RemainAfterExit = "yes";
    serviceConfig.ExecStart =
      let
        # - The initial backup repo must be created manually:
        #     $ sudo borg init --encryption none $repository
        # - Use writeScriptBin instead of writeScript, so that argv[0] (logged
        #   to the journal) doesn't include the long Nix store path hash.
        #   (Prefixing the ExecStart= command with '@' doesn't work because we
        #   start a shell (new process) that creates a new argv[0].)
        borgBackup = pkgs.writeScriptBin "borg-backup-script" ''
          #!${pkgs.bash}/bin/sh
          repository="/mnt/backup-disk/backup-maria.borg"

          # access the mountpoint now, to trigger automount (why is this needed?)
          if ! ls -ld /mnt/maria-pc_seagate_expansion_drive_4tb/; then
              echo "Failed to mount maria-pc"
              exit 1
          fi
          # Oops! autofs is considered a filesystem, so this check will always pass.
          if ! mountpoint /mnt/maria-pc_seagate_expansion_drive_4tb; then
              exit 1
          fi

          echo "Running 'borg create [...]'"
          borg create \
              --stats \
              --verbose \
              --list \
              --filter AME \
              --show-rc \
              --one-file-system \
              --exclude-caches \
              --exclude '*/$RECYCLE.BIN' \
              --exclude '*/System Volume Information' \
              --compression lz4 \
              "$repository::maria-pc_seagate_expansion_drive_4tb-$(date +%Y%m%dT%H%M%S)" \
              /mnt/maria-pc_seagate_expansion_drive_4tb/
          create_ret=$?

          echo "Running 'borg prune [...]'"
          borg prune \
              --stats \
              --verbose \
              --list \
              --show-rc \
              --keep-within=2d --keep-daily=7 --keep-weekly=4 --keep-monthly=6 \
              --prefix maria-pc_seagate_expansion_drive_4tb- \
              "$repository"
          prune_ret=$?

          echo "Running 'borg check [...]'"
          borg check \
              --verbose \
              --show-rc \
              "$repository"
          check_ret=$?

          # Exit with error if either command failed
          if [ $create_ret != 0 -o $prune_ret != 0 -o $check_ret != 0 ]; then
              echo "borg create, prune and/or check operation failed. Exiting with error."
              exit 1
          fi
        '';
        borgBackupScript = "${borgBackup}/bin/borg-backup-script";
      in
        borgBackupScript;
  };

  users.extraUsers.bfo.openssh.authorizedKeys.keys = with import ../misc/ssh-keys.nix; [
    bfo_at_mini
  ];
}
