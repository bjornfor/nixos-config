{ config, lib, pkgs, ... }:

let
  backupDiskMountpoint = "/mnt/backup-disk";

  # The external backup is split over two disk sets. Each set has 3 disks in
  # rotation. Complete sets are found on disks (n,n+3), for example (1,4). Each
  # week the disk set gets rotated in a round robin fashion.
  #
  # sourceDirs is relative to "${backupDiskMountpoint}/backups/hosts".
  backupSet0 = {
    sourceDirs = [
      "maria-pc"
    ];
    diskLabels = [
      "usb_4tb_backup1"
      "usb_4tb_backup2"
      "usb_4tb_backup3"
    ];
  };

  backupSet1 = {
    sourceDirs = [
      "media.local"
      "mini.local"
      "srv1.local"
      "whitetip.local"
    ];
    diskLabels = [
      "usb_4tb_backup4"
      "usb_4tb_backup5"
      "usb_4tb_backup6"
    ];
  };

  externalBackupDiskLabels = backupSet0.diskLabels ++ backupSet1.diskLabels;

  printBackupAgeInDays = pkgs.writeScript "print-backup-age-in-days" ''
    #!${pkgs.bash}/bin/sh
    set -e
    repository=$1
    if [ "x$repository" = "x" ]; then
        echo "Usage: $0 BORG_REPO_URL" >&2
        exit 1
    fi
    today=$(date +%Y-%m-%d)
    newest_backup_date=$(${pkgs.borgbackup}/bin/borg list --last 1 --json "$repository" | ${pkgs.jq}/bin/jq --raw-output ".archives[0].start")
    # POSIX sh:
    #n_days_old=$(echo "scale=0; ( $(date -d "$today" +%s) - $(date -d "$newest_backup_date" +%s) ) / (24*3600)" | bc)
    # bash(?):
    n_days_old=$(( ( $(date -d "$today" +%s) - $(date -d "$newest_backup_date" +%s) ) / (24*3600) ))
    if [ "$n_days_old" -eq "$n_days_old" ] 2>/dev/null
    then
        # $n_days_old is an integer
        echo "$n_days_old"
    else
        exit 1
    fi
  '';

  # Use borg for this?
  mkExternalBackupService = backupSetInfo: id:
  {
    description = "External Backup Set ${toString id}";
    # every morning (try to make it so all other backup jobs have completed
    # before this)
    startAt = "*-*-* 06:00:00";
    path = with pkgs; [ utillinux rsync ];
    script = ''
      num_copies=0
      for diskLabel in ${toString backupSetInfo.diskLabels}; do
         if [ -a "/dev/disk/by-label/$diskLabel" ]; then
             mp="/mnt/$diskLabel"
             set -x
             for srcDir in ${toString backupSetInfo.sourceDirs}; do
                 rsync -ai --delete "${backupDiskMountpoint}/backups/hosts/$srcDir/" "$mp/backups/hosts/$srcDir/"
             done
             set +x
             num_copies=$((num_copies + 1))
         fi
      done

      echo "Made $num_copies backup copies of: ${toString backupSetInfo.sourceDirs}"

      if [ "$num_copies" -eq 0 ]; then
          exit 1
      fi
    '';
    serviceConfig.SyslogIdentifier = "external-backup${toString id}";
  };

in
{
  fileSystems = {
    # My backup disk:
    "${backupDiskMountpoint}" = { device = "/dev/disk/by-label/backup2"; options = [ "nofail" ]; };
  };

  services.borg-backup = {
    enable = true;
    jobs."maria-pc" = rec {
      repository = "${backupDiskMountpoint}/backups/hosts/maria-pc/maria-pc.borg";
      archiveBaseName = "maria-pc_seagate_expansion_drive_4tb";
      rootDir = "/mnt/${archiveBaseName}";
      pathsToBackup = [ "." ];
      excludes = [
        "'pp:$RECYCLE.BIN'"
        "'pp:System Volume Information'"
      ];
      startAt = "*-*-* 01:15:00";  # every night
      preHook = ''
        if [ $(ls "/mnt/${archiveBaseName}" | wc -l) -lt 1 ]; then
            echo "/mnt/${archiveBaseName} has no files, assuming mount failure"
            exit 1
        fi
        # sanity check the backup source
        expect_path="/mnt/${archiveBaseName}/BILDER/BILDER 1"
        if [ ! -d "$expect_path" ]; then
            echo "$expect_path is missing. /mnt/${archiveBaseName} contents: $(echo; ls -F /mnt/${archiveBaseName})"
            exit 1
        fi
      '';
      postHook = ''
        # Email notification receivers.
        # Separate multiple addresses with comma and space (", ").
        to_recipients="$(cat /etc/marias-email-address.txt)"
        cc_recipients="bjorn.forsman@gmail.com"

        maybe_send_failure_notification()
        {
            n_days_old=$(${printBackupAgeInDays} "$repository")
            echo "Last backup is $n_days_old days old"
            if [ "$n_days_old" -ge 7 -a $(( "$n_days_old" % 7 )) = 0 ]; then
                echo "Warning: backup is old ($n_days_old days), sending email"
                send_email $n_days_old
            fi
        }

        send_email()
        {
            n_days_old=$1
            test "$n_days_old" -eq "$n_days_old" || { echo "ERROR: Programming error, n_days_old=$n_days_old is not an integer"; exit 1; }
            cat << EOM | sendmail -t
        From: "Mr. Robot" <noreply>
        To: $to_recipients
        Cc: $cc_recipients
        Subject: Obs, sikkerhetskopien din er gammel

        Hei Maria,

        Jeg heter Hal og en robot som Bjørn har laget.
        Hver natt tar jeg sikkerhetskopi av dataene fra den eksterne
        harddisken din og over til Bjørn sin PC. Men nå er det $n_days_old dager siden sist.

        Kan du la PCen stå på en natt slik at jeg får tatt en ny sikkerhetskopi for deg?

        Ha en fin dag!

        Mvh
        Hal 9000 / Bjørn Forsman
        EOM
        }

        # For test
        #send_email $(${printBackupAgeInDays} "$repository")
        #exit 0

        maybe_send_failure_notification
      '';
    };
  };

  services.samba = {
    enable = true;
    extraConfig = ''
      [borg-backups-maria-pc]
      path = /mnt/borg-backups-maria-pc/
      read only = yes
      guest ok = yes
    '';
  };

  systemd.services."borg-backup-default" = {
    onFailure = [ "status-email@%n" ];
  };
  systemd.services."borg-backup-maria-pc" = {
    # borg-backup-maria-pc is set to conflict with mount-borg-backup-maria-pc.
    # Because of that we have to start the latter _after_ the backup service.
    # If not, systemd would kill the backup service to resolve the conflict.
    # TODO: mount-borg-backup-maria-pc cause frequent borg repo locking issues
    #postStop = ''
    #  systemctl start mount-borg-backup-maria-pc
    #'';
  };

  systemd.services.external-backup0 = mkExternalBackupService backupSet0 0;
  systemd.services.external-backup1 = mkExternalBackupService backupSet1 1;

  systemd.services.mount-borg-backup-maria-pc = {
    description = "Mount Borg Backup Repository for Maria PC";
    # TODO: mount-borg-backup-maria-pc cause frequent borg repo locking issues
    enable = false;
    wantedBy = [ "multi-user.target" ];
    before = [ "samba.target" ];
    conflicts = [ "borg-backup-maria-pc.service" ];
    path = with pkgs; [
      borgbackup utillinux coreutils fuse
    ];
    preStart = ''
      # deal with stale mount processes
      fusermount -uz /mnt/borg-backups-maria-pc || true
      mkdir -p /mnt/borg-backups-maria-pc
    '';
    serviceConfig.ExecStart = ''
      ${pkgs.borgbackup}/bin/borg mount --foreground -o allow_other ${backupDiskMountpoint}/backups/hosts/maria-pc/maria-pc.borg /mnt/borg-backups-maria-pc
    '';
    postStop = ''
      # deal with stale mount processes
      fusermount -uz /mnt/borg-backups-maria-pc || true
    '';
  };

  systemd.services.backup-status = {
    description = "Send weekly status email about the backup";
    path = [ "/run/wrappers" /* for sendmail */ ];
    # Run after the local backup jobs (since otherwise the borg repos will be
    # locked). Remote backup jobs might still cause trouble.
    # TODO: This will not work until the backup jobs are made into "oneshot"
    # types.
    #after =
    #  map
    #    (x: "borg-backup-${x}.service")
    #    (lib.mapAttrsToList (n: v: n) config.services.borg-backup.jobs);
    startAt = "Mon *-*-* 17:00:00";  # weekly
    script =
      let
        jobsAsList =
          lib.mapAttrsToList
            (n: v: v)
            config.services.borg-backup.jobs;
      in
        ''
          set -e
          set -u

          overall_status_file=$(mktemp)
          trap "rm $overall_status_file" EXIT
          echo "GOOD" > "$overall_status_file"

          indent()
          {
              n=$1
              sed "s/^/$(for i in $(seq $n); do printf " "; done)/"
          }

          check_repo()
          {
              repository=$1
              indent=$2
              # "borg info" is more expensive than "borg list", but the latter doesn't include "nfiles"
              json_info=$(${pkgs.borgbackup}/bin/borg info --last 1 --json "$repository")
              latest_archive_name=$(echo "$json_info" | ${pkgs.jq}/bin/jq --raw-output ".archives[0].name")
              nfiles=$(echo "$json_info" | ${pkgs.jq}/bin/jq --raw-output ".archives[0].stats.nfiles")
              echo
              echo "$repository:" | indent $indent
              n_days_old=$(${printBackupAgeInDays} "$repository")
              if [ "$n_days_old" -ge 2 ]; then
                  if [ "x$set_overall_status" = "x1" ]; then
                      echo "BAD" > "$overall_status_file"
                  fi
                  suffix=" (WARNING)"
              else
                  suffix=
              fi
              if [ "x$latest_archive_name" = x ]; then
                  echo "\$latest_archive_name is empty, failed to get info from repo $repository (missing ssh key? repo locked?)" | indent $(($indent * 2))
                  if [ "x$set_overall_status" = "x1" ]; then
                      echo "BAD" > "$overall_status_file"
                  fi
              else
                  echo "$latest_archive_name -> nfiles=$nfiles, age_days=$n_days_old$suffix" | indent $(($indent * 2))
              fi
          }

          check_local_repos()
          {
              ${lib.concatMapStringsSep "\n"
                (job: ''
                  export BORG_RSH="${job.environment.BORG_RSH or ""}"
                  check_repo "${job.repository}" 4
                '')
                jobsAsList
              }
          }

          check_other_repos()
          {
              for repo in ${backupDiskMountpoint}/backups/hosts/*/*.borg; do
                  case "$repo" in
                    ${lib.concatMapStringsSep "\n"
                      (job: ''
                        ${job.repository}) true;;  # skip locally configured repo
                      '')
                      jobsAsList
                    }
                    *) check_repo "$repo" 4;;
                    esac
              done
          }

          set_overall_status=1
          local_repos_info=$(check_local_repos)
          set_overall_status=0
          other_repos_info=$(check_other_repos)

          overall_status=$(cat "$overall_status_file")

          cat << EOM | sendmail -t
          From: "Mr. Robot" <noreply>
          To: root
          Subject: Status of backup(s): $overall_status

          Locally configured repos:
          $local_repos_info

          Other repos (not affecting overall status):
          $other_repos_info

          - Mr. Robot
          EOM
        '';
  };

  systemd.automounts = [
    { where = "/mnt/maria-pc_seagate_expansion_drive_4tb";
      wantedBy = [ "multi-user.target" ];
    }
  ] ++ (map (x:
          {
            where = "/mnt/${x}";
            wantedBy = [ "multi-user.target" ];
            automountConfig.TimeoutIdleSec = "5min";
          }) externalBackupDiskLabels
       );

  systemd.mounts = [
    { what = "//maria-pc/seagate_expansion_drive_4tb";
      where = "/mnt/maria-pc_seagate_expansion_drive_4tb";
      type = "cifs";
      options = "ro,credentials=/root/.credentials.maria-pc,uid=bf,gid=users,iocharset=utf8";
    }
  ] ++ (map (x:
          {
            what = "/dev/disk/by-label/${x}";
            where = "/mnt/${x}";
          }) externalBackupDiskLabels
       );

  environment.systemPackages = with pkgs; [
    borgbackup
    cifs_utils  # for mount.cifs, needed for cifs filesystems in systemd.mounts.
  ];

  users.extraUsers = {
    # A system user for backup automation
    backup = {
      description = "Backup user";
      uid = 600;
      group = "backup";
      home = "/var/lib/backup";
      createHome = true;
      useDefaultShell = true;
    };
  };

  users.extraGroups = {
    backup = { gid = 600; };
  };

  users.extraUsers.backup.openssh.authorizedKeys.keys = with config.local.resources.sshKeys; [
    (''command="dir=\"${backupDiskMountpoint}/backups/hosts/media.local\" && cd \"$dir\" && borg serve --restrict-to-path \"$dir\"",restrict '' + media.root.backup)
    (''command="dir=\"${backupDiskMountpoint}/backups/hosts/mini.local\" && cd \"$dir\" && borg serve --restrict-to-path \"$dir\"",restrict '' + mini.root.backup)
    (''command="dir=\"${backupDiskMountpoint}/backups/hosts/whitetip.local\" && cd \"$dir\" && borg serve --restrict-to-path \"$dir\"",restrict '' + whitetip.root.backup)
    # For convenience, allow bf too
    (''command="dir=\"${backupDiskMountpoint}/backups/hosts/mini.local\" && cd \"$dir\" && borg serve --restrict-to-path \"$dir\"",restrict '' + mini.bf.default)
    (''command="dir=\"${backupDiskMountpoint}/backups/hosts/whitetip.local\" && cd \"$dir\" && borg serve --restrict-to-path \"$dir\"",restrict '' + whitetip.bf.default)
  ];
}
