{ config, lib, pkgs, ... }:

{
  services.apcupsd = {
    enable = true;
    hooks.doshutdown = ''
      HOSTNAME=$(${pkgs.nettools}/bin/hostname)
      printf "Subject: apcupsd: $HOSTNAME is shutting down\n" | ${pkgs.msmtp}/bin/msmtp -C /home/bfo/.msmtprc bjorn.forsman@gmail.com
    '';
    hooks.onbattery = ''
      HOSTNAME=$(${pkgs.nettools}/bin/hostname)
      printf "Subject: apcupsd: $HOSTNAME is running on battery\n" | ${pkgs.msmtp}/bin/msmtp -C /home/bfo/.msmtprc bjorn.forsman@gmail.com
    '';
    hooks.offbattery = ''
      HOSTNAME=$(${pkgs.nettools}/bin/hostname)
      printf "Subject: apcupsd: $HOSTNAME is running on mains power\n" | ${pkgs.msmtp}/bin/msmtp -C /home/bfo/.msmtprc bjorn.forsman@gmail.com
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
