{ config, lib, pkgs, ... }:

{
  environment.etc."mdadm.conf".text = ''
    MAILADDR root
  '';

  systemd.services.mdadm-monitor = {
    description = "Mdadm Raid Array Monitor";
    wantedBy = [ "multi-user.target" ];
    after = [ "postfix.service" ];
    serviceConfig.ExecStart = "${pkgs.mdadm}/bin/mdadm --monitor --scan";
  };

  # Hack to run degraded arrays.
  # TODO: Let upstream (mdadm) udev rules invoke upstream systemd service
  # units. dracut initrds do this, NixOS initrd does not.
  boot.initrd.preLVMCommands = ''
    for dev in /dev/md*; do
        if [ -b "$dev" ]; then
            mdadm --run "$dev"
        fi
    done
  '';

  systemd.services.mdadm-scrubbing = {
    description = "Mdadm Raid Array Scrubbing";
    startAt = "Sun 06:00:00";
    script = ''
      for md in /sys/block/md*; do
          echo check > "$md/md/sync_action"
      done
    '';
  };

  # Scrub on next boot if system was powered off during last schedule.
  systemd.timers.mdadm-scrubbing.timerConfig.Persistent = true;
}
