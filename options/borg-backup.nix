# NixOS module for BorgBackup.

/*
Restore everything:
$ cd /mnt/restore
$ [sudo] borg extract -v --list --numeric-owner /mnt/backup-disk/repo-name::archive-name

Restore from remote repository:
$ [sudo BORG_RSH='ssh -i /home/bf/.ssh/id_rsa'] borg extract -v --list --numeric-owner --remote-path="sudo borg" ssh://bf@server/mnt/backup-disk/repo-name::archive-name

Interactive restore (slower than 'borg extract'):
$ borg mount /mnt/backup-disk/repo-name /mnt/fuse-mountpoint
$ ls -1 /mnt/fuse-mountpoint
my-machine-20150220T234453
my-machine-20150321T114708
... restore files (cp/rsync) ...
$ borg umount /mnt/fuse-mountpoint
*/

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg-backup;

  # - The initial backup repo must be created manually:
  #     $ sudo borg init --encryption none $repository
  # - "icfg" is short for "instance configuration"
  mkBackupScript = icfg: pkgs.writeScript "borg-backup" ''
      #!${pkgs.bash}/bin/sh
      repository="${icfg.repository}"
      archive="${icfg.archiveBaseName}-$(date +%Y%m%dT%H%M%S)"
      archive_in_progress="$archive.IN_PROGRESS"
      archive_unsuccessful="$archive.UNSUCCESSFUL"

      on_exit()
      {
          exit_status=$?
          # Reset the EXIT handler, or else we're called again on 'exit' below
          trap - EXIT
          echo "Running postHook"
          ${icfg.postHook}
          echo "Done, exiting with status $exit_status."

          # Allow systemd/journal to associate the last messages from this unit
          # before exit. Yep, it's a race.
          sleep 3
          exit $exit_status
      }
      trap 'on_exit' INT TERM QUIT EXIT

      # Inject the environment variables here, so they'll be available also
      # when not run under systemd.
      ${lib.concatMapStringsSep "\n" (x: x) (lib.mapAttrsFlatten (n: v: "export ${n}=\"${v}\"") icfg.environment)}

      echo "Running preHook"
      ${icfg.preHook}

      # Prevent borg from looking at autofs mountpoints. (Because if the
      # underlying filesystem cannot be mounted, stat() returns ENODEV, borg
      # prints a warning and exits with status 1. Even with --one-file-system.)
      autofs_excludes=$(cat /proc/mounts | while read src mountpoint fstype rest; do
          test "$fstype" = autofs && printf "%s %q\n" --exclude "$mountpoint"; done)

      echo "Running 'borg create [...]'"
      (cd "${icfg.rootDir}" && borg create \
          --stats \
          --verbose \
          --list \
          --filter ME \
          --show-rc \
          --one-file-system \
          $autofs_excludes \
          --exclude-caches \
          ${if icfg.excludeNix then ''
            --exclude /etc/nix/nix.conf \
            --exclude /nix/ \
          '' else ''\''}
          ${lib.concatMapStringsSep "\n" (x: "--exclude ${x} \\") icfg.excludes}
          --compression lz4 \
          "$repository::$archive_in_progress" \
          ${lib.concatStringsSep " " icfg.pathsToBackup})
      create_ret=$?

      if [ $create_ret = 0 ]; then
          final_archive_name="$archive"
      else
          final_archive_name="$archive_unsuccessful"
      fi
      echo "Renaming archive: $archive_in_progress -> $final_archive_name"
      (cd "${icfg.rootDir}" && borg rename "$repository::$archive_in_progress" "$final_archive_name") || create_ret=1

      echo "Running 'borg prune [...]'"
      (cd "${icfg.rootDir}" && borg prune \
          --stats \
          --verbose \
          --list \
          --show-rc \
          --keep-within=2d --keep-daily=7 --keep-weekly=4 --keep-monthly=6 \
          --prefix "${icfg.archiveBaseName}-" \
          "$repository")
      prune_ret=$?

      # Rate limit repository checks, since they are quite expensive.
      repository_dir="$(dirname ${icfg.repository})"
      repository_name="$(basename ${icfg.repository})"
      repository_check_stampfile="$repository_dir/.$repository_name.check_stamp"
      repo_check_min_interval_in_days=1
      repo_check_is_old=0
      if [ ! -f "$repository_check_stampfile" ]; then
          repo_check_is_old=1
      elif [ "$(find "$repository_check_stampfile" -ctime "+$repo_check_min_interval_in_days")" ]; then
          repo_check_is_old=1
      fi
      if [ "$repo_check_is_old" -eq 1 ];  then
          check_day=Sunday
          this_day=$(date +%A)
          if [ "$this_day" = "$check_day" ];  then
              echo "Running 'borg check [...]' (since a check is due and today is $this_day)"
              (cd "${icfg.rootDir}" && borg check \
                  --verbose \
                  --show-rc \
                  "$repository")
              check_ret=$?
              touch "$repository_check_stampfile"
          else
              echo "Skipping 'borg check' since today is not $check_day (it's $this_day)"
              check_ret=0
          fi
      else
          echo "Skipping 'borg check' since the last check was done less than $repo_check_min_interval_in_days day(s) ago"
          check_ret=0
      fi

      # Exit with error if either command failed
      if [ $create_ret != 0 ] || [ $prune_ret != 0 ] || [ $check_ret != 0 ]; then
          echo "borg create, prune and/or check operation failed. Exiting with error."
          false  # sets $? for the postHook
      fi
    '';

  mkService = name: value: {
    name = "borg-backup-${name}";
    value = {
      description = "Borg Backup Service ${name}";
      path = with pkgs; [
        borgbackup utillinux coreutils gawk openssh
        "/run/wrappers"  # for sendmail
      ];
      serviceConfig.SyslogIdentifier = "borg-backup-${name}"; # else HASH-borg-backup
      serviceConfig.ExecStart = mkBackupScript value;
    } // (if value.startAt != null then { startAt = value.startAt; } else { });
  };

in
{
  options.services.borg-backup = {

    enable = mkEnableOption "enable borg backup service to take nightly backups.";

    jobs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {

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
            default = config.networking.hostName;
            defaultText = "config.networking.hostName";
            description = ''
              Complete archive names look like "$archiveBaseName-DATE".
            '';
          };

          excludeNix = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to exclude /nix/ (and the generated file /etc/nix/nix.conf)
              from the backup. Set it to false if you want to be able to do full
              system restore from your backup. Set it to true if you want to save
              some disk space and are okay with having to recover your system by
              running nixos-install. A prerequisite for this option is that
              pathsToBackup includes the Nix store.
            '';
          };

          excludes = mkOption {
            type = types.listOf types.str;
            default = [
              "/tmp/"
              "/var/tmp/"
              "/var/swapfile"
              "'/home/*/.cache/'"
              "'/home/*/.thumbnails/'"
              "'/home/*/.nox/'"
              "'*/.Trash*/'"
              "'*/$RECYCLE.BIN'"
              "'*/System Volume Information'"
            ];
            description = ''
              List of files/directories/patterns to exclude from the backup. Each
              element will be passed to borg as "--exclude elem".
            '';
          };

          rootDir = mkOption {
            type = types.path;
            default = "/";
            example = [ "/mnt/remote-fs" ];
            description = ''
              The directory from where borg commands will be run. Relateive paths
              in <option>pathsToBackup</option> are relative to this directory.
            '';
          };

          pathsToBackup = mkOption {
            type = types.listOf types.str;
            default = [ "/" "/boot" ];
            example = [ "/home" "/srv" ];
            description = ''
              List of paths to backup, relative to <option>rootdir</option>, unless using absolute paths.
              The backup does not cross filesystem
              boundaries, so each filesystem (mountpoint) you want to have backed up
              must be listed here.
            '';
          };

          preHook = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Shell commands to run before backing up. Abort the backup with
              'exit N'.
            '';
          };

          postHook = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Shell commands to run just before exit, for example to undo resource
              allocations done by the preHook. These commands are run even on
              unsuccessful backups (e.g if the preHook calls 'exit'). The
              (planned) exit status is stored in the "exit_status" variable and
              can be modified by this hook, if desired. Do not call 'exit' from
              this hook, that may cause the most recent log output to not be
              associated with this backup job (it's a kernel/systemd/journal race).
            '';
          };

          startAt = mkOption {
            type = with types; nullOr str;
            default = "*-*-* 01:15:00";
            description = ''
              When to run the backup, in systemd.time(7) format. If null, the
              backup job will not be started automatically. Use this to start
              the backup by some other means -- either manually or by
              configuring your own systemd dependencies (e.g. start backup when
              a certain USB disk is inserted).
            '';
          };

          environment = mkOption {
            type = with types; attrsOf str;
            default = {};
            example = lib.literalExample ''
              { BORG_PASSCOMMAND = "cat /path/to/password-file";
                BORG_RSH = "ssh -i /root/.ssh/id_backup";
              }
            '';
            description = ''
              Extra environment variables, set in the job script.
            '';
          };

        };
      });
      default = {};
      description = ''
        Each attribute of this option defines a BorgBackup job. The name of
        each systemd service is "borg-backup-ATTR". If there is an attribute
        named "default", its repository path will be exported in the BORG_REPO
        environment variable, for easy (interactive) access.
      '';
    };

  };

  config = mkIf cfg.enable {

    assertions = [
      { assertion = builtins.length (builtins.attrNames cfg.jobs) > 0;
        message = "No backup jobs defined in services.borg-backup.jobs.*";
      }
    ] ++
      (mapAttrsToList
        (name: value: {
          assertion = config.services.borg-backup.jobs."${name}".repository != "";
          message = "Please specify a value in services.borg-backup.jobs.${name}.repository.";
        })
        cfg.jobs)
    ++
      (mapAttrsToList
        (name: value: {
          assertion = config.services.borg-backup.jobs."${name}".pathsToBackup != [];
          message = "Please specify a value in services.borg-backup.jobs.${name}.pathsToBackup.";
        })
        cfg.jobs);

    # for convenience
    environment.sessionVariables = mkIf (cfg.jobs ? "default") {
      BORG_REPO = "${cfg.jobs."default".repository}";
    };

    systemd.services = mapAttrs' mkService cfg.jobs;

  };

}
