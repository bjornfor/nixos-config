{ config, pkgs, lib, ... }:

let
  backupDiskMountpoint = "/mnt/backup-disk";

  # A LVM snapshot will be made of this VG + LV, from which the backup will be
  # made.
  vgname = "vg0";
  lvname = "lvol0";
in
{
  services.borg-backup = {
    jobs."default" = rec {
      repository = "${backupDiskMountpoint}/backups/hosts/srv1.local/srv1.borg";
      rootDir = "/tmp/backup-temp-root";
      pathsToBackup = [
        "etc/nixos"
        "home"
        "root"
        "var/lib/gitolite"
        "var/lib/nextcloud"
        "var/lib/syncthing"
      ];
      preHook = ''
        {
            # Alternative size specs: `--extents 100%FREE` or `--size 10G`
            snapshotName="${vgname}-${lvname}-snapshot"
            ${pkgs.lvm2}/bin/lvcreate --extents 100%FREE --snapshot --name "$snapshotName" "/dev/${vgname}/${lvname}" &&
            mkdir "${rootDir}" &&
            mount -o ro "/dev/${vgname}/$snapshotName" "${rootDir}" &&
            # /boot is not snapshotted, but files in there are only changed
            # when doing nixos-rebuild.
            mount -o bind /boot "${rootDir}/boot"
        } || { echo "setupHook failed"; exit 1; }
      '';
      postHook = ''
        # Retry unmounting a few times, to give borg time to exit after
        # receiving e.g. SIGTERM.
        umount_retry()
        {
            for i in $(seq 60); do
                if umount $1; then
                    echo "Successfully unmounted after $i attempt(s): $1"
                    break
                else
                    sleep 1
                fi
            done
        }
        # postHook can manipulate $exit_status
        mountpoint -q "${rootDir}/boot" && { umount_retry "${rootDir}/boot" || exit_status=1; }
        mountpoint -q "${rootDir}" && { umount_retry "${rootDir}" || exit_status=1; }
        test -d "${rootDir}" && { rmdir "${rootDir}" || exit_status=1; }
        if "${pkgs.lvm2}/bin/lvdisplay" "/dev/${vgname}/$snapshotName" >/dev/null 2>&1; then
            "${pkgs.lvm2}/bin/lvremove" --yes "/dev/${vgname}/$snapshotName" || exit_status=1
        fi
      '';
    };
  };
}
