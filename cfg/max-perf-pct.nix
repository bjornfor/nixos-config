# Store and restore /sys/devices/system/cpu/intel_pstate/max_perf_pct state.
#
# Background: My laptop has terrible thermal design and a very noisy fan. I
# generally operate it with max_perf_pct=70 and would like to automate this.
# This module adds a script called max_perf_pct that can be invoked to adjust
# the setting (tip: bind to a keyboard shortcut).

{ config, lib, pkgs, ... }:

let
  stateFile = "/var/lib/max_perf_pct/state";
in
{
  environment.systemPackages = with pkgs; [ my.max_perf_pct ];

  systemd.services.max_perf_pct = {
    description = "(Re)store max_perf_pct Sysfs Attribute";
    wantedBy = [ "multi-user.target" ];
    #path = [ "/run/wrappers" /* For sudo. Unneeded when run as root. */ ];
    serviceConfig.ExecStart = pkgs.writeScript "max_perf_pct_start" ''
      #!${pkgs.bash}/bin/sh
      test -f "${stateFile}" || exit 0
      saved_value=$(cat "${stateFile}" 2>/dev/null)
      if ! test "$saved_value" -eq "$saved_value" 2>/dev/null; then
          echo "error: cannot load state from ${stateFile} because it is empty or has non-numeric contents: $saved_value"
      else
          echo "Restoring state from ${stateFile}: $saved_value"
          ${pkgs.my.max_perf_pct}/bin/max_perf_pct "$saved_value"
      fi
    '';
    serviceConfig.ExecStop = pkgs.writeScript "max_perf_pct_stop" ''
      #!${pkgs.bash}/bin/sh
      saved_value=$(${pkgs.my.max_perf_pct}/bin/max_perf_pct)
      echo "Saving state to ${stateFile}: $saved_value"
      echo "$saved_value" > "${stateFile}"
    '';
    serviceConfig.SyslogIdentifier = "max_perf_pct";
    serviceConfig.Type = "oneshot";
    serviceConfig.ProtectSystem = "strict";
    serviceConfig.RemainAfterExit = true;
    serviceConfig.StateDirectory = "max_perf_pct";
  };
}
