{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg-backup;
in
{
  options.services.borg-backup = {

    enable = mkEnableOption "enable borg backup service to take nightly backups.";

    repository = mkOption {
      type = types.str;
      default = "";
      example = "/mnt/backups/backup.borg";
      description = ''
        Path to Borg repository where the backup will be stored.
      '';
    };

    archiveBaseName = mkOption {
      type = types.str;
      default = "{hostname}";
      description = ''
        Complete archive names look like "$archiveBaseName-DATE".
      '';
    };

    pathsToBackup = mkOption {
      type = types.listOf types.str;
      default = [ "/" ];
      example = [ "/home" "/srv" ];
      description = ''
        List of paths to backup.
      '';
    };

    preHook = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Shell commands to run before backing up. Abort backup if 'exit N'.
      '';
    };

    postHook = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Shell commands to run after backing up, pruning and checking the repository.
      '';
    };

  };

  config = mkIf cfg.enable {

    assertions = [
      { assertion = config.services.borg-backup.repository != "";
        message = "Please specify a value in services.borg-backup.repository.";
      }
      { assertion = config.services.borg-backup.pathsToBackup != [];
        message = "Please specify a value in services.borg-backup.pathsToBackup.";
      }
    ];

    systemd.services.borg-backup = {
      # Restore everything:
      # $ cd /mnt/restore
      # $ [sudo] borg extract -v --list --numeric-owner /mnt/backup-disk/repo-name::archive-name
      #
      # Restore from remote repository:
      # $ [sudo BORG_RSH='ssh -i /home/bfo/.ssh/id_rsa'] borg extract -v --list --numeric-owner --remote-path="sudo borg" ssh://bfo@server/mnt/backup-disk/repo-name::archive-name
      #
      # Interactive restore (slower than 'borg extract'):
      # $ borg mount /mnt/backup-disk/repo-name /mnt/fuse-mountpoint
      # $ ls -1 /mnt/fuse-mountpoint
      # my-machine-20150220T234453
      # my-machine-20150321T114708
      # ... restore files (cp/rsync) ...
      # $ borg umount /mnt/fuse-mountpoint
      #
      #
      # == Disaster recovery
      #
      # 1. Boot NixOS live CD/USB
      #
      # 2. Partition, format and mount disk(s) on /mnt.
      #    If booting in EFI mode, remember that the FAT32 formatted EFI System
      #    Partition must be mounted on /mnt/boot. (If booting in BIOS mode you
      #    don't _have_ to make a separate boot partition, as long as your
      #    root filesystem is supported by GRUB.)
      #
      # 3. Install borg (`nix-env -iA nixos.borgbackup`) and set $BORG_REPO:
      #    export BORG_REPO=ssh://user@server/mnt/backup-disk/repo-name
      #    (Make sure the root user in the live CD/USB environment has SSH keys
      #    to log onto 'user@server'.)
      #
      # 4. List available archives, chose one to restore from.
      #    borg list --remote-path="sudo borg" $BORG_REPO
      #
      # 5. Restore files:
      #    cd /mnt && borg extract -v --list --numeric-owner --remote-path="sudo borg" $BORG_REPO::archive-name
      #
      # 6. Check that bootloader and filesystem(s) is set up correctly in
      #    NixOS configuration (which disk LABEL/UUID to use etc.). If
      #    restoring on new HW, pay attention when updating
      #    hardware-configuration.nix (`nixos-generate-config --dir /tmp`).
      #
      # 7. nixos-install
      enable = true;
      description = "Borg Backup Service";
      startAt = "*-*-* 01:15:00";  # see systemd.time(7)
      environment = {
        BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes";
      };
      path = with pkgs; [
        borgbackup utillinux coreutils
      ];
      serviceConfig.ExecStart =
        let
          # - The initial backup repo must be created manually:
          #     $ sudo borg init --encryption none $repository
          # - Use writeScriptBin instead of writeScript, so that argv[0] (logged
          #   to the journal) doesn't include the long Nix store path hash.
          #   (Prefixing the ExecStart= command with '@' doesn't work because we
          #   start a shell (new process) that creates a new argv[0].)
          borgBackup = pkgs.writeScriptBin "borg-backup" ''
            #!${pkgs.bash}/bin/sh
            repository="${cfg.repository}"

            die()
            {
                echo "$*"
                # Allow systemd to associate this message with the unit before
                # exit. Yep, it's a race.
                sleep 3
                exit 1
            }

            ${cfg.preHook}

            echo "Running 'borg create [...]'"
            borg create \
                --stats \
                --verbose \
                --list \
                --filter AME \
                --show-rc \
                --one-file-system \
                --exclude-caches \
                --exclude /etc/nix/nix.conf \
                --exclude /nix/ \
                --exclude /tmp/ \
                --exclude /var/tmp/ \
                --exclude '/home/*/.cache/' \
                --exclude '/home/*/.thumbnails/' \
                --exclude '/home/*/.nox/' \
                --exclude '*/.Trash*/' \
                --exclude '*/$RECYCLE.BIN' \
                --exclude '*/System Volume Information' \
                --compression lz4 \
                "$repository::${cfg.archiveBaseName}-$(date +%Y%m%dT%H%M%S)" \
                ${lib.concatStringsSep " " cfg.pathsToBackup}
            create_ret=$?

            echo "Running 'borg prune [...]'"
            borg prune \
                --stats \
                --verbose \
                --list \
                --show-rc \
                --keep-within=2d --keep-daily=7 --keep-weekly=4 --keep-monthly=6 \
                --prefix ${cfg.archiveBaseName}- \
                "$repository"
            prune_ret=$?

            echo "Running 'borg check [...]'"
            borg check \
                --verbose \
                --show-rc \
                "$repository"
            check_ret=$?

            ${cfg.postHook}

            # Exit with error if either command failed
            if [ $create_ret != 0 -o $prune_ret != 0 -o $check_ret != 0 ]; then
                die "borg create, prune and/or check operation failed. Exiting with error."
            fi
          '';
          borgBackupScript = "${borgBackup}/bin/borg-backup-script";
        in
          borgBackupScript;
    };

  };

}
