{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./webserver.nix
    ../../cfg/apcupsd.nix
    ../../cfg/base-big.nix
    ../../cfg/cgit.nix
    ../../cfg/clamav.nix
    ../../cfg/disable-suspend.nix
    ../../cfg/gitolite.nix
    ../../cfg/git-daemon.nix
    ../../cfg/backup-server.nix
    ../../cfg/smart-daemon.nix
    ../../cfg/transmission.nix
  ];

  fileSystems = {
    "/".device = "/dev/disk/by-label/240gb";
    "/mnt/data".device = "/dev/disk/by-uuid/87c75c5e-67d5-4a61-949a-e514542db339";
    "/mnt/data".options = [ "nofail" ];
    "/mnt/ssd-120".device = "/dev/disk/by-id/ata-KINGSTON_SH103S3120G_50026B722600AA5F-part1";
    "/mnt/ssd-120".options = [ "nofail" ];
  };

  boot.loader.grub.device =
    "/dev/disk/by-id/ata-KINGSTON_SH103S3240G_50026B722A027195";

  networking.hostName = "mini";

  environment.systemPackages = with pkgs; [
  ];

  services = {

    xserver.displayManager.gdm.autoLogin.enable = true;
    xserver.displayManager.gdm.autoLogin.user = "bf";

    ddclient = {
      enable = true;
      # Use imperative configuration to keep secrets out of the (world
      # readable) Nix store. If this option is not set, the NixOS options from
      # services.ddclient.* will be used to populate /etc/ddclient.conf.
      configFile = "/var/lib/ddclient/secrets/ddclient.conf";
    };

    samba = {
      enable = true;
      extraConfig = ''
        [media]
        path = /mnt/data/media
        read only = yes
        guest ok = yes

        [pictures]
        path = /mnt/data/pictures/
        read only = yes
        guest ok = yes

        [software]
        path = /mnt/data/software/
        read only = yes
        guest ok = yes
      '' + (if config.services.transmission.enable then ''

        [torrents]
        path = /srv/torrents
        read only = no
        guest ok = yes
        force user = transmission
      '' else "");
    };

    minidlna = {
      enable = true;
      mediaDirs = [ "/mnt/data/media" ];
    };

    munin-node.extraConfig = ''
      cidr_allow 192.168.1.0/24
    '';

    mysql = {
      enable = true;
      package = pkgs.mysql;
      extraOptions = ''
        # This is added in the [mysqld] section in my.cnf
      '';
    };

    nfs.server = {
      enable = true;
      exports = ''
        /nix/ 192.168.1.0/24(ro,subtree_check)
        #/srv/nfs/wandboard/ 192.168.1.0/24(rw,no_root_squash,no_subtree_check)
      '';
    };

    tftpd = {
      enable = true;
      path = "/srv/tftp";
    };

    ntopng = {
      # It constantly breaks due to geoip database hash changes.
      # TODO: See if fetching geoip databases can be done with a systemd
      # service instead of using Nix.
      #enable = true;
      extraConfig = "--disable-login";
    };
  };

  systemd.services.archive-photos-from-syncthing = {
    description = "Archive photos from Syncthing";
    startAt = "weekly";
    path = with pkgs; [ exiftool "/run/wrappers" ];
    serviceConfig.User = "bf";
    serviceConfig.SyslogIdentifier = "archive-photos";
    script = ''
      # Where to look for files (images and videos).
      input_dir=/var/lib/syncthing/lg-h930-foto/Camera
      # Files newer than this are not moved.
      days_to_keep=30
      # Files older than $days_to_keep are moved here, in YEAR + MONTH
      # subdirectories.
      pictures_archive=/mnt/data/pictures

      for dir in "$input_dir" "$pictures_archive"; do
          if ! [ -d "$dir" ]; then
              echo "No such directory: $dir" >&2
              exit 1
          fi
      done

      on_exit()
      {
          exit_status=$?

          echo "Sending email with job status"
          cat << EOM | sendmail -t
      From: root
      To: bjorn.forsman@gmail.com
      Subject: Archived photos from Syncthing

      This is an automatic message sent from host $HOSTNAME showing the status
      of the archive-photos-from-syncthing job:

      $(systemctl status archive-photos-from-syncthing -n10000)
      EOM

          exit "$exit_status"
      }
      trap 'on_exit' INT TERM QUIT EXIT

      # For testing, add/change these exiftool args:
      # * Add "-o ." to copy instead of move and change the -d value to "$HOME/tmp/exiftool/%Y/%Y-%m".
      echo "Processing files in $input_dir. Files older than $days_to_keep days will be moved to $pictures_archive in YEAR + MONTH subdirs."
      find "$input_dir" -type f -mtime +"$days_to_keep" -print0 | xargs -0 --no-run-if-empty exiftool '-Directory<CreateDate' -d "$pictures_archive/%Y/%Y-%m" -verbose
    '';
  };

  users.extraUsers.bf.openssh.authorizedKeys.keys = with import ../../misc/ssh-keys.nix; [
    whitetip.bf.default
    (''command="./bin/restricted-hamster-scp-command",restrict '' + virtualbox_at_work.bf.default)
    (''command="/run/current-system/sw/bin/uptime",restrict '' + my_phone.user.default)
  ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "17.03";
}
