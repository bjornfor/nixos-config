{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lighttpd.collectd-graph-panel;

  phpfpmSocketName = "/run/phpfpm/collectd-graph-panel.sock";

  collectd-graph-panel-0_4_1_255 =
    pkgs.stdenv.mkDerivation rec {
      name = "collectd-graph-panel-${version}";
      version = "0.4.1-225-g4aef0f7";
      src = pkgs.fetchzip {
        name = "${name}-src";
        url = "https://github.com/pommi/CGP/archive/4aef0f7e017cdf7e2b92dc9a9f700368506879e9.tar.gz";
        sha256 = "1m5mqr4zmm57irrp6csri62ylxh7nns4vhrmi4jpnn8jsqx4v4sl";
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
        \$CONFIG['typesdb'] = '${pkgs.collectd}/share/collectd/types.db';
        # Plugins to show on the overview page
        \$CONFIG['overview'] = array('load', 'cpu', 'memory', 'swap', 'sensors', 'uptime');
        ?>
        EOF
      '';
    };
in
{
  options.services.lighttpd.collectd-graph-panel = {

    enable = mkEnableOption "Collectd Graph Panel in lighttpd";

    package = mkOption {
      type = types.package;
      default = collectd-graph-panel-0_4_1_255;
      defaultText = "collectd-graph-panel-0_4_1_255";
      description = "Collectd Graph Panel package to use.";
    };

    urlPrefix = mkOption {
      type = types.str;
      default = "/collectd";
      example = "/";
      description = ''
        The prefix below the web server root URL to serve Collectd Graph Panel.
      '';
    };

    vhostsPattern = mkOption {
      type = types.str;
      default = ".*";
      example = "(myserver1.example|myserver2.example)";
      description = ''
        A virtual host regexp filter. Change it if you want Collectd Graph
        Panel to only be served from some host names, instead of all.
      '';
    };

  };

  config = mkIf (config.services.lighttpd.enable && cfg.enable) {

    services.lighttpd = {
      enableModules = [ "mod_alias" "mod_fastcgi" ];
      extraConfig = ''
        $HTTP["host"] =~ "${cfg.vhostsPattern}" {
            alias.url += ( "${cfg.urlPrefix}" => "${cfg.package}/" )
            $HTTP["url"] =~ "^${cfg.urlPrefix}" {
                index-file.names += ( "index.php" )
                fastcgi.server = (
                    ".php" => (
                        "phpfpm-collectd-graph-panel" => (
                            "socket" => "${phpfpmSocketName}",
                        )
                    )
                )
            }
        }
      '';
    };

    services.phpfpm.poolConfigs = {
      collectd-graph-panel = ''
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
  };

}
