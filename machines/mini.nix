{ config, lib, pkgs, ... }:

let
  myDomain = "bforsman.name";
  phpSockName1 = "/run/phpfpm/pool1.sock";
  backupDiskMountpoint = "/mnt/backup-disk";
in
{
  imports = [
    ../config/base-big.nix
    ../options/nextcloud.nix
  ];

  fileSystems = {
    "/".device = "/dev/disk/by-label/240gb";
    "/mnt/data".device = "/dev/disk/by-label/1.5tb";
    "/mnt/ssd-120".device = "/dev/disk/by-id/ata-KINGSTON_SH103S3120G_50026B722600AA5F-part1";
    "/mnt/ssd-120".options = [ "nofail" ];
    # My backup disk:
    "${backupDiskMountpoint}" = { device = "/dev/disk/by-label/backup2"; };
  };

  boot.loader.grub.device =
    "/dev/disk/by-id/ata-KINGSTON_SH103S3240G_50026B722A027195";

  networking.hostName = "mini";

  nixpkgs.config = {
    #virtualbox.enableExtensionPack = true;
  };

  environment.systemPackages = with pkgs; [
  ];

  virtualisation.virtualbox.host.enable = true;

  services = {

    smartd = {
      enable = true;
      autodetect = true;  # monitor all drives found on startup
      # See smartd.conf(5) man page for details about these options:
      # "-a": enable all checks
      # "-o VALUE": enable/disable automatic offline testing on device (on/off)
      # "-s REGEXP": do a short test every day at 1am and a long test every
      #              sunday at 1am.
      defaults.autodetected = "-a -o on -s (S/../.././01|L/../../7/01)";
      notifications = {
        mail.enable = true;
        x11.enable = true;
        #test = true; # create a notification on service startup, for test
      };
    };

    postfix = {
      enable = true;
      domain = myDomain;
      hostname = myDomain;
      rootAlias = "bjorn.forsman@gmail.com";
    };

    lighttpd = {
      enable = true;
      #mod_status = true; # don't expose to the public
      mod_userdir = true;
      enableModules = [ "mod_alias" "mod_proxy" "mod_access" "mod_fastcgi" "mod_redirect" ];
      extraConfig =
        let
          collectd-graph-panel =
            pkgs.stdenv.mkDerivation rec {
              name = "collectd-graph-panel-${version}";
              version = "0.4.1";
              src = pkgs.fetchzip {
                name = "${name}-src";
                url = "https://github.com/pommi/CGP/archive/v${version}.tar.gz";
                sha256 = "14jm7jidp4z0vcd9rcblrqkp6mfbmvc548biwrjylm6yvdjgqb9l";
              };
              buildCommand = ''
                mkdir -p "$out"
                cp -r "$src"/. "$out"
                chmod +w "$out"/conf
                cat > "$out"/conf/config.local.php << EOF
                <?php
                \$CONFIG['datadir'] = '/var/lib/collectd';
                \$CONFIG['rrdtool'] = '${pkgs.rrdtool}/bin/rrdtool';
                \$CONFIG['graph_type'] = 'canvas';
                ?>
                EOF
              '';
            };
        in ''
        $HTTP["host"] =~ ".*" {
          dir-listing.activate = "enable"
          alias.url += ( "/munin" => "/var/www/munin" )

          # Reverse proxy for transmission bittorrent client
          proxy.server = (
            "/transmission" => ( "transmission" => (
                                 "host" => "127.0.0.1",
                                 "port" => 9091
                               ) )
          )
          # Fix transmission URL corner case: get error 409 if URL is
          # /transmission/ or /transmission/web. Redirect those URLs to
          # /transmission (no trailing slash).
          url.redirect = ( "^/transmission/(web)?$" => "/transmission" )

          alias.url += ( "/collectd" => "${collectd-graph-panel}" )
          $HTTP["url"] =~ "^/collectd" {
            index-file.names += ( "index.php" )
          }

          fastcgi.server = (
            ".php" => (
              "localhost" => (
                "socket" => "${phpSockName1}",
              ))
          )

          # Block access to certain URLs if remote IP is not on LAN
          $HTTP["remoteip"] !~ "^(192\.168\.1|127\.0\.0\.1)" {
              $HTTP["url"] =~ "(^/transmission/.*|^/server-.*|^/munin/.*|^/collectd.*)" {
                  url.access-deny = ( "" )
              }
          }
        }

        # Lighttpd SSL/HTTPS documentation:
        # http://redmine.lighttpd.net/projects/lighttpd/wiki/Docs_SSL

        $HTTP["host"] == "bforsman.name" {
          $SERVER["socket"] == ":443" {
            ssl.engine = "enable"
            ssl.pemfile = "/etc/lighttpd/certs/bforsman.name.pem"
            ssl.ca-file = "/etc/lighttpd/certs/1_Intermediate.crt"
          }
          $HTTP["scheme"] == "http" {
            $HTTP["url"] =~ "^/nextcloud" {
              url.redirect = ("^/.*" => "https://bforsman.name$0")
            }
          }
        }

        $HTTP["host"] == "mariaogbjorn.no" {
          $SERVER["socket"] == ":443" {
            ssl.engine = "enable"
            ssl.pemfile = "/etc/lighttpd/certs/mariaogbjorn.no.pem"
            ssl.ca-file = "/etc/lighttpd/certs/1_Intermediate.crt"
          }
        }

        # TODO: Reduce config duplication between vhosts
        $HTTP["host"] == "sky.mariaogbjorn.no" {
          $SERVER["socket"] == ":443" {
            ssl.engine = "enable"
            ssl.pemfile = "/etc/lighttpd/certs/sky.mariaogbjorn.no.pem"
            ssl.ca-file = "/etc/lighttpd/certs/1_Intermediate.crt"
          }
          url.redirect += ("^/$" => "/nextcloud/")
          $HTTP["scheme"] == "http" {
            $HTTP["url"] =~ "^/nextcloud" {
              url.redirect = ("^/.*" => "https://sky.mariaogbjorn.no$0")
            }
          }
        }
      '';
      nextcloud.enable = true;
      gitweb.enable = true;
      cgit = {
        enable = true;
        configText = ''
          # HTTP endpoint for git clone is enabled by default
          #enable-http-clone=1

          # Specify clone URLs using macro expansion
          clone-url=http://${myDomain}/cgit/$CGIT_REPO_URL https://${myDomain}/cgit/$CGIT_REPO_URL git@${myDomain}:$CGIT_REPO_URL

          # Enable 'stats' page and set big upper range
          max-stats=year

          # Allow download of tar.gz, tar.bz2, tar.xz and zip-files
          snapshots=tar.gz tar.bz2 tar.xz zip

          # Enable caching of up to 1000 output entries
          cache-size=1000

          # about-formatting.sh is impure (doesn't work)
          #about-filter=${pkgs.cgit}/lib/cgit/filters/about-formatting.sh
          # Add simple plain-text filter
          about-filter=${pkgs.writeScript "cgit-about-filter.sh"
            ''
              #!${pkgs.stdenv.shell}
              echo "<pre>"
              ${pkgs.coreutils}/bin/cat
              echo "</pre>"
            ''
          }

          # Search for these files in the root of the default branch of
          # repositories for coming up with the about page:
          readme=:README.asciidoc
          readme=:README.txt
          readme=:README
          readme=:INSTALL.asciidoc
          readme=:INSTALL.txt
          readme=:INSTALL

          # Group repositories on the index page by sub-directory name
          section-from-path=1

          # scan-path must be last so that earlier settings take effect when
          # scanning
          scan-path=/srv/git
        '';
      };
    };

    phpfpm.poolConfigs = lib.mkIf config.services.lighttpd.enable {
      pool1 = ''
        listen = ${phpSockName1}
        listen.group = lighttpd
        user = nobody
        pm = dynamic
        pm.max_children = 75
        pm.start_servers = 10
        pm.min_spare_servers = 5
        pm.max_spare_servers = 20
        pm.max_requests = 500
      '';
    };

    apcupsd.enable = true;

    transmission.enable = true;

    # TODO: Change perms on /var/lib/collectd from 700 to something more
    # permissive, at least group readable?
    # The NixOS service currently only sets perms *once*, so I've manually
    # loosened it up for now, to allow lighttpd to read RRD files.
    collectd = {
      enable = true;
      extraConfig = ''
        # Interval at which to query values. Can be overwritten on per plugin
        # with the 'Interval' option.
        # WARNING: You should set this once and then never touch it again. If
        # you do, you will have to delete all your RRD files.
        Interval 10

        # Load plugins
        LoadPlugin apcups
        LoadPlugin contextswitch
        LoadPlugin cpu
        LoadPlugin df
        LoadPlugin disk
        LoadPlugin ethstat
        LoadPlugin interface
        LoadPlugin irq
        LoadPlugin virt
        LoadPlugin load
        LoadPlugin memory
        LoadPlugin network
        LoadPlugin nfs
        LoadPlugin processes
        LoadPlugin rrdtool
        LoadPlugin sensors
        LoadPlugin tcpconns
        LoadPlugin uptime

        <Plugin "virt">
          Connection "qemu:///system"
        </Plugin>

        <Plugin "df">
          MountPoint "/"
          MountPoint "/mnt/data/"
          MountPoint "/mnt/backup-disk/"
        </Plugin>

        # Output/write plugin (need at least one, if metrics are to be persisted)
        <Plugin "rrdtool">
          CacheFlush 120
          WritesPerSecond 50
        </Plugin>
      '';
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

        [backups]
        path = ${backupDiskMountpoint}/backups/
        read only = yes
        guest ok = yes

        [borg-backups]
        path = /mnt/borg-backups/
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

    munin-cron = {
      hosts = ''
        [ul30a]
        address ul30a.local
      '';
    };

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

  systemd.services.my-backup = {
    enable = true;
    description = "My Backup";
    startAt = "*-*-* 01:15:00";  # see systemd.time(7)
    path = with pkgs; [ bash rsync openssh utillinux gawk nettools time cifs_utils ];
    serviceConfig.ExecStart = /home/bfo/bin/backup.sh;
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
    startAt = "*-*-* 05:15:00";  # see systemd.time(7)
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
        #   to the journal) doesn't include the long nix store path hash.
        #   (Prefixing the ExecStart= command with '@' doesn't work because we
        #   start a shell (new process) that creates a new argv[0].)
        borgBackup = pkgs.writeScriptBin "borg-backup-script" ''
          #!${pkgs.bash}/bin/sh
          repository="${backupDiskMountpoint}/backups/backup.borg"

          #systemctl stop borg-backup-mountpoint

          echo "Running 'borg create [...]'"
          borg create \
              --stats \
              --verbose \
              --list \
              --filter AME \
              --show-rc \
              --one-file-system \
              --exclude-caches \
              --exclude /nix/ \
              --exclude /tmp/ \
              --exclude /var/tmp/ \
              --exclude '/home/*/.cache/' \
              --exclude '/home/*/.thumbnails/' \
              --exclude '/home/*/.nox/' \
              --exclude '*/.Trash*/' \
              --compression lz4 \
              "$repository::{hostname}-$(date +%Y%m%dT%H%M%S)" \
              / /mnt/data
          create_ret=$?

          echo "Running 'borg prune [...]'"
          borg prune \
              --stats \
              --verbose \
              --list \
              --show-rc \
              --keep-within=2d --keep-daily=7 --keep-weekly=4 --keep-monthly=6 \
              --prefix {hostname}- \
              "$repository"
          prune_ret=$?

          echo "Running 'borg check [...]'"
          borg check \
              --verbose \
              --show-rc \
              "$repository"
          check_ret=$?

          #systemctl start borg-backup-mountpoint

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

  systemd.services.borg-backup-mountpoint = {
    # disabled as it's a constant source of locking issues (preventing backups)
    enable = false;
    description = "Mount Borg Backup Repository";
    wantedBy = [ "multi-user.target" ];
    before = [ "samba.target" ];
    # "borg create" cannot be used at the same time as "borg mount" is active
    # on the same repo. (attic hung forever, borg should (AFAIK) exit with
    # error due to inability to create exclusive lock.) The "conflicts"
    # directive doesn't start the conflicted service afterwards, so we
    # explicitly stop/start this service in borg-backup.service instead.
    #conflicts = [ "borg-backup.service" ];]
    path = with pkgs; [
      borgbackup utillinux coreutils fuse
    ];
    preStart = ''
      mkdir -p /mnt/borg-backups
    '';
    serviceConfig.ExecStart = ''
      ${pkgs.borgbackup}/bin/borg mount --foreground -o allow_other ${backupDiskMountpoint}/backups/backup.borg /mnt/borg-backups
    '';
    postStop = ''
      fusermount -u /mnt/borg-backups || true
    '';
  };

  users.extraUsers.bfo.openssh.authorizedKeys.keys = [
    ''ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCfy7XFi35G277tbjGzFeFdbtz8c3b9dQcBpE9KlcVVKMG9mMzVQeLJkehqi/NGyzV7DcJgvFW0vFJaRbQbOVuIlnC3rCwO+NUJW+48aarnna1Izv6ihHp5vprYhZT9AANfUUsaCy5ZBVljlJ34S8gJNvmq7oogh9ioi9hE3LvdZMC0M6k2WZG5+lPlDWbNjuWlYF9e9XVJlopU+xfNy98u0djyBo2urkqtNT8vXu49JarKpxgi3tMDv2pZFNNICukWsg8EEH6YIhJjsiO0RdnanzO/yQK2/SQtq0GjnzEaRilAgiUnGHC7f7iOBeNhc+hUcKltBlWmPsF9ZV5txZDT bfo@whitetip''

    ''command="./bin/restricted-hamster-scp-command",restrict ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDGj+nNg5BUBNNb/vqOKeBApKG2HGiNDk8QXqwyCFOm8VIMohQaI2gKOOOiS759MBIThHYqLw1p5aVVl5tzIwjPLA8vTy9BOuCw6AayoWFQLwEKSmpz6L3NSpqhyyGm4H0mmcr4fzT5qngc3abWxchS9Z8Of/AAKHEemf94B0vbN/LVlnzFzSc8FVDJHjGeYQXZYTHLkyg9/6gY09nbFr+++lvoObUAQ63cFxTCJ2lNiOxMtOijCER7onMCdA39opgSaG628Qlg2r22nvlROz8vUjdfLZNKMUL4NePEeW2G/gsWTOijtSiL/y/ZpMrG3XNt/U2Y+FTOa9ridvwZkclT bf@bf-VirtualBox (at work)''

    ''command="/run/current-system/sw/bin/uptime",restrict ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDZ63+kGCJbSI8P8LThqXJHZdiGWHpR7K/NUkimWn+3r4y22JhuRLpUHnHRfvPm16HIbrVwrHbZ6vxqvxx7hP9UGRTdRT9HjOvVoOQGIYjRtjrRiMHE/DmrBxdQ5FtQVeARKcNCWYIlubtuxg1c6ZD0fScs5yWrlumblsQxJgqS5K6csyh9yZL8rtBC0VqkroynMoYONqTTAAnx6lg9X6t2FZ3SFqCZ5VYk9DkwLZNIrwwEF87tQSuCSTX8pKw9THP0H07pafR0hWwKHuhPqbK7qlE1ZXzVtbujg/GndLbjFFV7Lpkc5h5B+fC4VBAiaKG9DQSV5LNRjrolprQkijNiFNqojnsCSJVDHSercDSTLNsN2wNPKXUlzkNyWEnefvPFrW1vPBoTF8YrPICNOi8mGLkX+ygP0ROycuKupSqkfAjXqdabAnuHNZHI1gY9j4/qlK5YhgbOu1pWVe9xVKCEfR0MG/iTi83ExiDlkzGgOcFkiDoUaKF6HMM2w6u+pgwDSsP8jmHrUuGqib3mMm3M7VMoGvxQE+T8bQ53G1/z/FI3xITpnNUs61DtUxf6uSCYJFDE5vRYSAnPW9L7/dLo5klJbDbyGyHgneFeGb5gdQEqhUZHXHXwCPyH5fn2XLA6DErMGWAvEqNVs6p2XO54UY/HuKnjr1W8eMqLVMpvVw== My phone''
  ];
}