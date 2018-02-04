{ config, lib, pkgs, ... }:

let
  myDomain = "bforsman.name";
  phpSockName1 = "/run/phpfpm/pool1.sock";
  backupDiskMountpoint = "/mnt/backup-disk";
  acmeChallengesDir = "/var/www/challenges/";
in
{
  imports = [
    ../cfg/apcupsd.nix
    ../cfg/base-big.nix
    ../cfg/cgit.nix
    ../cfg/clamav.nix
    ../cfg/gitolite.nix
    ../cfg/git-daemon.nix
    ../cfg/smart-daemon.nix
    ../cfg/transmission.nix
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

  users.extraUsers."lighttpd".extraGroups = [ "git" ];

  security.acme.certs = {
    "${myDomain}" = {
      email = "bjorn.forsman@gmail.com";
      webroot = acmeChallengesDir;
      extraDomains =
        { "mariaogbjorn.no" = null;
          "sky.mariaogbjorn.no" = null;
        };
      # TODO: When lighttpd 1.4.46 comes out we can switch from "restart" to "reload"
      postRun = ''
        systemctl restart lighttpd
      '';
    };
  };

  services = {

    ddclient = {
      enable = true;
      # Use imperative configuration to keep secrets out of the (world
      # readable) Nix store. If this option is not set, the NixOS options from
      # services.ddclient.* will be used to populate /etc/ddclient.conf.
      configFile = "/var/lib/ddclient/secrets/ddclient.conf";
    };

    postfix = {
      domain = myDomain;
      hostname = myDomain;
    };

    lighttpd = {
      enable = true;
      #mod_status = true; # don't expose to the public
      mod_userdir = true;
      enableModules = [ "mod_alias" "mod_proxy" "mod_access" "mod_fastcgi" "mod_redirect" ];
      extraConfig = ''
        # Uncomment one or more of these in case something doesn't work right
        #debug.log-request-header = "enable"
        #debug.log-request-header-on-error = "enable"
        #debug.log-response-header = "enable"
        #debug.log-file-not-found = "enable"
        #debug.log-request-handling = "enable"
        #debug.log-condition-handling = "enable"

        $HTTP["host"] =~ ".*" {
          dir-listing.activate = "enable"
          alias.url += ( "/munin" => "/var/www/munin" )

          # for Let's Encrypt certificates (NixOS security.acme.certs option)
          alias.url += ( "/.well-known/acme-challenge" => "${acmeChallengesDir}/.well-known/acme-challenge" )

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

          fastcgi.server = (
            ".php" => (
              "localhost" => (
                "socket" => "${phpSockName1}",
              ))
          )

          # Block access to certain URLs if remote IP is not on LAN
          $HTTP["remoteip"] !~ "^(192\.168\.1|127\.0\.0\.1)" {
              $HTTP["url"] =~ "(^/transmission/.*|^/server-.*|^/munin/.*|^${config.services.lighttpd.collectd-graph-panel.urlPrefix}.*)" {
                  url.access-deny = ( "" )
              }
          }
        }

        # Lighttpd SSL/HTTPS documentation:
        # http://redmine.lighttpd.net/projects/lighttpd/wiki/Docs_SSL

        $HTTP["host"] == "${myDomain}" {
          $SERVER["socket"] == ":443" {
            ssl.engine = "enable"
            ssl.pemfile = "/var/lib/acme/${myDomain}/full.pem"
          }
          $HTTP["scheme"] == "http" {
            $HTTP["url"] =~ "^/nextcloud" {
              url.redirect = ("^/.*" => "https://${myDomain}$0")
            }
          }
        }

        $HTTP["host"] == "mariaogbjorn.no" {
          $SERVER["socket"] == ":443" {
            ssl.engine = "enable"
            ssl.pemfile = "/var/lib/acme/${myDomain}/full.pem"
          }
        }

        # TODO: Reduce config duplication between vhosts
        $HTTP["host"] == "sky.mariaogbjorn.no" {
          $SERVER["socket"] == ":443" {
            ssl.engine = "enable"
            ssl.pemfile = "/var/lib/acme/${myDomain}/full.pem"
          }
          url.redirect += ("^/$" => "/nextcloud/")
          $HTTP["scheme"] == "http" {
            $HTTP["url"] =~ "^/nextcloud" {
              url.redirect = ("^/.*" => "https://sky.mariaogbjorn.no$0")
            }
          }
        }
      '';
      collectd-graph-panel.enable = true;
      nextcloud.enable = true;
      gitweb.enable = true;
      gitweb.projectroot = "/srv/git/repositories";
      gitweb.extraConfig = ''
        our $projects_list = '/srv/git/projects.list';
      '';
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

        <Plugin "apcups">
          Host "localhost"
          Port "3551"
        </Plugin>

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

        [borg-backups-maria-pc]
        path = /mnt/borg-backups-maria-pc/
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

  services.gitolite-mirror.enable = true;
  services.gitolite-mirror.repoUrls = [
    "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
    "https://github.com/nixos/nix"
    "https://github.com/nixos/nixpkgs"
    "https://github.com/nixos/nixops"
    "https://github.com/nixos/nixpkgs"
  ];

  services.borg-backup = {
    enable = true;
    instances."default" = {
      repository = "${backupDiskMountpoint}/backups/backup.borg";
      archiveBaseName = "{hostname}";
      pathsToBackup = [ "/" "/mnt/data" ];
      postHook = ''
        systemctl start borg-backup-maria-pc
      '';
    };
    instances."maria-pc" = rec {
      repository = "${backupDiskMountpoint}/backups/backup-maria-pc.borg";
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
        # Email notification receivers.
        # Separate multiple addresses with comma and space (", ").
        to_recipients="$(cat /etc/marias-email-address.txt)"
        cc_recipients="bjorn.forsman@gmail.com"

        backup_age_in_days()
        {
            today=$(date +%Y-%m-%d)
            newest_backup_date=$(borg info "$repository"::"$(borg list "$repository" | tail -1 | awk '{print $1}')" | awk '/Time \(start\)/ {print $4}')
            # POSIX sh:
            #n_days_old=$(echo "scale=0; ( $(date -d "$today" +%s) - $(date -d "$newest_backup_date" +%s) ) / (24*3600)" | bc)
            # bash(?):
            n_days_old=$(( ( $(date -d "$today" +%s) - $(date -d "$newest_backup_date" +%s) ) / (24*3600) ))
            if [ "$n_days_old" -eq "$n_days_old" ] 2>/dev/null
            then
                # $n_days_old is an integer
                echo "$n_days_old"
            else
                echo "-1"
            fi
        }

        maybe_send_failure_notification()
        {
            n_days_old=$(backup_age_in_days)
            echo "Last backup is $n_days_old days old"
            if [ "$n_days_old" -ge 7 -a $(( "$n_days_old" % 7 )) = 0 ]; then
                echo "Warning: backup is old ($n_days_old days), sending email"
                send_email $(n_days_old)
            fi
        }

        dieHook() {
            maybe_send_failure_notification
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
        #send_email $(backup_age_in_days)
        #exit 0

        if [ $(ls /mnt/${archiveBaseName} | wc -l) -lt 1 ]; then
            die "/mnt/${archiveBaseName} has no files, assuming mount failure"
        fi
        # sanity check the backup source
        expect_path="/mnt/${archiveBaseName}/BILDER/BILDER 1"
        if [ ! -d "$expect_path" ]; then
            die "$expect_path is missing. /mnt/${archiveBaseName} contents: $(echo; ls -F /mnt/${archiveBaseName})"
        fi
      '';
    };
  };

  systemd.services."borg-backup-default" = {
    onFailure = [ "status-email@%n" ];
  };
  systemd.services."borg-backup-maria-pc" = {
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
      for mp in /run/media/bfo/usb_4tb_backup*; do
         if mountpoint "$mp"; then
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
      ${pkgs.borgbackup}/bin/borg mount --foreground -o allow_other ${backupDiskMountpoint}/backups/backup-maria-pc.borg /mnt/borg-backups-maria-pc
    '';
    postStop = ''
      # deal with stale mount processes
      fusermount -uz /mnt/borg-backups-maria-pc || true
    '';
  };

  users.extraUsers.bfo.openssh.authorizedKeys.keys = with import ../misc/ssh-keys.nix; [
    bfo_at_whitetip
    (''command="./bin/restricted-hamster-scp-command",restrict '' + bf_at_work)
    (''command="/run/current-system/sw/bin/uptime",restrict '' + my_phone)
  ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "17.03";
}
