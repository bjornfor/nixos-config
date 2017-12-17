{ config, lib, pkgs, ... }:

{
  services.apcupsd = {
    enable = true;
    hooks.doshutdown = ''
      HOSTNAME=$(${pkgs.nettools}/bin/hostname)
      printf "Subject: apcupsd: $HOSTNAME is shutting down\n" | /run/wrappers/bin/sendmail root
    '';
    hooks.onbattery = ''
      HOSTNAME=$(${pkgs.nettools}/bin/hostname)
      printf "Subject: apcupsd: $HOSTNAME is running on battery\n" | /run/wrappers/bin/sendmail root
    '';
    hooks.offbattery = ''
      HOSTNAME=$(${pkgs.nettools}/bin/hostname)
      printf "Subject: apcupsd: $HOSTNAME is running on mains power\n" | /run/wrappers/bin/sendmail root
    '';
    configText = ''
      UPSTYPE usb
      NISIP 127.0.0.1
      BATTERYLEVEL 75
      MINUTES 10
      #TIMEOUT 10  # for debugging, shutdown after N seconds on batteries
    '';
  };
}
