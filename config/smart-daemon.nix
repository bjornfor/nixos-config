{ config, lib, pkgs, ... }:

{
  services = {
    smartd = {
      enable = true;
      autodetect = true; # monitor all devices found on startup
      # See smartd.conf(5) man page for details about these options:
      # "-a": enable all checks
      # "-o VALUE": enable/disable automatic offline testing on device (on/off)
      # "-s REGEXP": do a short test every day at 3am and a long test every
      #              sunday at 3am.
      defaults.autodetected = "-a -o on -s (S/../.././03|L/../../7/03)";
      notifications = {
        mail.enable = true;
        x11.enable = true;
        #test = true; # send notification on service startup, for test
      };
    };

    # To receive email notifications we need a "sendmail".
    # Postfix can be used for this, example below.
    #postfix = {
    #  enable = true;
    #  domain = "mydomain.example";
    #  rootAlias = "your.email@somewhere.example";
    #  extraConfig = ''
    #    inet_interfaces = loopback-only
    #  '';
    #};
  };
}
