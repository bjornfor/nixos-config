{ config, lib, pkgs, ... }:

let
  myDomain = "bforsman.name";
  phpSockName1 = "/run/phpfpm/pool1.sock";
  backupDiskMountpoint = "/mnt/backup-disk";
  acmeChallengesDir = "/var/www/challenges/";
in
{
  imports = [
    ../config/base-big.nix
    ../config/clamav.nix
    ../config/gitolite.nix
    ../config/git-daemon.nix
    ../config/smart-daemon.nix
    ../config/transmission.nix
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

        $HTTP["url"] =~ "^/cgit" {
          setenv.add-environment += (
            ${let
                pythonEnv = pkgs.python3.buildEnv.override {
                  extraLibs = with pkgs.python3Packages; [ pygments ];
                };
                cgitPath = with pkgs; lib.makeBinPath [ pythonEnv ];
              in ''
              "PATH" => "${cgitPath}:" + env.PATH
            ''}
          )
        }
      '';
      collectd-graph-panel.enable = true;
      nextcloud.enable = true;
      gitweb.enable = true;
      gitweb.projectroot = "/srv/git/repositories";
      gitweb.extraConfig = ''
        our $projects_list = '/srv/git/projects.list';
      '';
      cgit = {
        enable = true;
        configText = ''
          # HTTP endpoint for git clone is enabled by default
          #enable-http-clone=1

          # Specify clone URLs using macro expansion
          clone-url=http://${myDomain}/cgit/$CGIT_REPO_URL https://${myDomain}/cgit/$CGIT_REPO_URL git://${myDomain}/$CGIT_REPO_URL git@${myDomain}:$CGIT_REPO_URL

          # Show pretty commit graph
          #enable-commit-graph=1

          # Show number of affected files per commit on the log pages
          enable-log-filecount=1

          # Show number of added/removed lines per commit on the log pages
          enable-log-linecount=1

          # Enable 'stats' page and set big upper range
          max-stats=year

          # Allow download of archives in the following formats
          snapshots=tar.xz zip

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

          commit-filter=${pkgs.writeScript "cgit-commit-filter.sh" ''
            #!${pkgs.stdenv.shell}
            regex=
            # This expression generates links to commits referenced by their SHA1.
            regex=$regex'
            s|\b([0-9a-fA-F]{7,40})\b|<a href="./?id=\1">\1</a>|g'

            # This expression generates links to a bugtracker.
            #regex=$regex'
            #s|#([0-9]+)\b|<a href="http://YOUR_SERVER/?bug=\1">#\1</a>|g'

            # Apply the transformation
            sed -re "$regex"
          ''}

          source-filter=${pkgs.cgit}/lib/cgit/filters/syntax-highlighting.py

          # Search for these files in the root of the default branch of
          # repositories for coming up with the about page:
          readme=:README.asciidoc
          readme=:README.adoc
          readme=:README.txt
          readme=:README

          # Group repositories on the index page by sub-directory name
          section-from-path=1

          # Allow using gitweb.* keys
          enable-git-config=1

          # (Can be) maintained by gitolite
          project-list=/srv/git/projects.list

          # scan-path must be last so that earlier settings take effect when
          # scanning
          scan-path=/srv/git/repositories
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
    repository = "${backupDiskMountpoint}/backups/backup.borg";
    archiveBaseName = "{hostname}";
    pathsToBackup = [ "/" "/mnt/data" ];
    preHook = ''
      #systemctl stop borg-backup-mountpoint
    '';
    postHook = ''
      #systemctl start borg-backup-mountpoint
    '';
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

  users.extraUsers.bfo.openssh.authorizedKeys.keys = with import ../misc/ssh-keys.nix; [
    bfo_at_whitetip
    (''command="./bin/restricted-hamster-scp-command",restrict '' + bf_at_work)
    (''command="/run/current-system/sw/bin/uptime",restrict '' + my_phone)
  ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "17.03";
}
