let
  backupDiskMountpoint = "/mnt/backup-disk";
in
{
  services.borg-backup = {
    jobs."default" = {
      repository = "${backupDiskMountpoint}/backups/hosts/srv1.local/srv1.borg";
      pathsToBackup = [
        "/etc/nixos"
        "/home"
        "/root"
        "/var/lib/gitolite"
        "/var/lib/nextcloud"
        "/var/lib/syncthing"
      ];
    };
  };
}
