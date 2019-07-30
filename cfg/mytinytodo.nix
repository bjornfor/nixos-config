# NixOS module for running http://www.mytinytodo.net/ on lighttpd.
#
# Update to new version (copied from http://www.mytinytodo.net/faq.php)
# 
#  1. Download, unpack and replace all files excluding directory 'db'
#     (automatically handled by this module).
#  2. Run 'setup.php' and upgrade database if required. 

{ config, lib, pkgs, ... }:

with lib;

let
  appName = "mytinytodo";

  appDir = "/var/lib/${appName}";

  phpfpmSocketName = "/run/phpfpm/${appName}.sock";

  mytinytodo =
    pkgs.stdenv.mkDerivation rec {
      name = "mytinytodo-${version}";
      version = "1.4.3";
      src = pkgs.fetchzip {
        name = "${name}-src";
        url = "https://bitbucket.org/maxpozdeev/mytinytodo/downloads/mytinytodo-v${version}.zip";
        sha256 = "0rv5bjd7p2c9wlaxadq3aiavqbxwgyjwp4b0975nghcwp6207my2";
      };
      buildCommand = ''
        mkdir -p "$out"
        cp -r "$src"/. "$out"

        echo "Tweaking CSS"
        chmod -R u+w "$out"
        css_mod="input[type=checkbox]
        { /* Double-sized checkboxes, because normal size boxes are difficult to hit on phone */
          transform: scale(2);
          padding: 10px;
        }"
        echo "$css_mod" >> "$out/themes/default/style.css"  # default style
        echo "$css_mod" >> "$out/themes/default/pda.css"    # for phones
      '';
    };
in
{
  config = {

    services.lighttpd = {
      enableModules = [ "mod_alias" "mod_fastcgi" ];
      extraConfig = ''
        $HTTP["host"] =~ ".*" {
            alias.url += ( "/${appName}" => "${appDir}/" )
            $HTTP["url"] =~ "^/${appName}" {
                index-file.names += ( "index.php" )
                fastcgi.server = (
                    ".php" => (
                        "${appName}" => (
                            "socket" => "${phpfpmSocketName}",
                        )
                    )
                )
            }

            # Found by listing .htaccess files
            $HTTP["url"] =~ "(^/${appName}/db.*|^/${appName}/tmp.*|^/${appName}/lang.*)" {
                url.access-deny = ( "" )
            }
        }
      '';
    };

    services.phpfpm.poolConfigs = {
      mytinytodo = ''
        listen = ${phpfpmSocketName}
        listen.group = lighttpd
        user = lighttpd
        group = lighttpd
        pm = dynamic
        pm.max_children = 75
        pm.start_servers = 10
        pm.min_spare_servers = 5
        pm.max_spare_servers = 20
        pm.max_requests = 500
      '';
    };

    systemd.services.lighttpd.preStart = ''
      echo "Setting up ${appName} in ${appDir}"
      if [ -f "${appDir}/db/todolist.db" ]; then
          maybe_exclude_db="--exclude db/"
      fi
      ${pkgs.rsync}/bin/rsync -a --checksum --delete $maybe_exclude_db "${mytinytodo}/" "${appDir}/"
      chown -R lighttpd:lighttpd "${appDir}"
      chmod u+w "${appDir}/db"
      chmod u+w "${appDir}/db/config.php"
      chmod u+w "${appDir}/db/todolist.db"
    '';
  };
}
