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
  };

  # NixOS 18.09+ renamed services.lighttpd.gitweb.* to services.gitweb.*
  services.gitweb =
    lib.mkIf (lib.versionAtLeast (lib.version or lib.nixpkgsVersion) "18.09")
      gitwebConfig;

}
