{ config, lib, pkgs, ... }:

let
  myDomain = "bforsman.name";
  phpSockName1 = "/run/phpfpm/pool1.sock";
  acmeChallengesDir = "/var/www/challenges/";

  gitwebConfig = {
    projectroot = "${config.services.gitolite.dataDir}/repositories";
    extraConfig = ''
      our $projects_list = '${config.services.gitolite.dataDir}/projects.list';
    '';
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ../../cfg/apcupsd.nix
    ../../cfg/base-big.nix
    ../../cfg/cgit.nix
    ../../cfg/clamav.nix
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

    xserver.displayManager.gdm.autoLogin.enable = true;
    xserver.displayManager.gdm.autoLogin.user = "bf";

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
      # NixOS 18.09+ renamed services.lighttpd.gitweb.* to services.gitweb.*
      gitweb = { enable = true; } //
        (if lib.versionOlder (lib.version or lib.nixpkgsVersion) "18.09"
        then gitwebConfig
        else {});
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

  # Disable the GNOME3/GDM auto-suspend feature that cannot be disabled in GUI!
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

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

  # NixOS 18.09+ renamed services.lighttpd.gitweb.* to services.gitweb.*
  services.gitweb =
    lib.mkIf (lib.versionAtLeast (lib.version or lib.nixpkgsVersion) "18.09")
      gitwebConfig;

  users.extraUsers.bf.openssh.authorizedKeys.keys = with import ../../misc/ssh-keys.nix; [
    whitetip.bf.default
    (''command="./bin/restricted-hamster-scp-command",restrict '' + virtualbox_at_work.bf.default)
    (''command="/run/current-system/sw/bin/uptime",restrict '' + my_phone.user.default)
  ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "17.03";
}
