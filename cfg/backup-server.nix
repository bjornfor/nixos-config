{ config, lib, pkgs, ... }:

let
  backupDiskMountpoint = "/mnt/backup-disk";
  externalBackupDiskLabels = [
    "usb_4tb_backup4"
    "usb_4tb_backup5"
    "usb_4tb_backup6"
  ];
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
in
{
  fileSystems = {
    # My backup disk:
    "${backupDiskMountpoint}" = { device = "/dev/disk/by-label/backup2"; options = [ "nofail" ]; };
  };

  services.borg-backup = {
    enable = true;
    jobs."default" = {
      repository = "${backupDiskMountpoint}/backups/hosts/mini.local/mini.borg";
      pathsToBackup = [ "/" "/mnt/data" ];
      postHook = ''
        systemctl start borg-backup-maria-pc
      '';
    };
    jobs."maria-pc" = rec {
      repository = "${backupDiskMountpoint}/backups/hosts/maria-pc/maria-pc.borg";
      archiveBaseName = "maria-pc_seagate_expansion_drive_4tb";
      rootDir = "/mnt/${archiveBaseName}";
      pathsToBackup = [ "." ];
      excludes = [
        "'pp:$RECYCLE.BIN'"
        "'pp:System Volume Information'"
      ];
      # Started by "parent" backup job instead of a timer.
      startAt = null;
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
    postStop = ''
      systemctl start mount-borg-backup-maria-pc
      sleep 10
      systemctl start external-backup
    '';
  };

  # Use borg for this?
  systemd.services.external-backup = {
    description = "External Backup";
    path = with pkgs; [ utillinux rsync ];
    script = ''
      num_copies=0
      for dev in ${lib.concatMapStringsSep " " (x: "/dev/disk/by-label/${x}") externalBackupDiskLabels}; do
         if [ -a "$dev" ]; then
             mp="/mnt/$(basename "$dev")"
             set -x
             rsync -ai --delete "${backupDiskMountpoint}/backups/" "$mp"/backups/
             set +x
             num_copies=$((num_copies + 1))
         fi
      done
      echo "Made $num_copies backup copies"
    '';
    serviceConfig.Restart = "on-failure";
  };

  systemd.services.mount-borg-backup-maria-pc = {
    description = "Mount Borg Backup Repository for Maria PC";
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

  users.extraUsers.backup.openssh.authorizedKeys.keys = with import ../misc/ssh-keys.nix; [
    (''command="dir=\"${backupDiskMountpoint}/backups/hosts/media.local\" && cd \"$dir\" && borg serve --restrict-to-path \"$dir\"",restrict '' + media.root.backup)
    (''command="dir=\"${backupDiskMountpoint}/backups/hosts/whitetip.local\" && cd \"$dir\" && borg serve --restrict-to-path \"$dir\"",restrict '' + whitetip.root.backup)
    # For convenience, allow bf too
    (''command="dir=\"${backupDiskMountpoint}/backups/hosts/whitetip.local\" && cd \"$dir\" && borg serve --restrict-to-path \"$dir\"",restrict '' + whitetip.bf.default)
  ];
}
