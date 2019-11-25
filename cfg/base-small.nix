{ config, lib, pkgs, ... }:

{
  imports = [
    ./avahi.nix
    ./kernel.nix
    ./keyboard.nix
    ./shell.nix

    ../options/borg-backup.nix
    ../options/cifs-user-mount.nix
    ../options/collectd-graph-panel.nix
    ../options/gitolite-mirror.nix
    ../options/nextcloud.nix
    ../options/pia/pia-nm.nix
  ];

  # List swap partitions activated at boot time.
  #swapDevices = [
  #  { device = "/dev/disk/by-label/swap"; }
  #];

  boot.loader.grub = {
    enable = true;
    version = 2;
    # Define on which hard drive you want to install Grub. Set to "nodev" to
    # not install it to the MBR at all, but only install the boot menu. This is
    # handy if you have NixOS installed on a USB stick that gets a different
    # device name when you plug it in different ports or on different machines.
    # Then you install using "/dev/..." and set it to "nodev" afterwards.
    #device = /*lib.mkDefault*/ "nodev";
  };

  hardware.cpu.amd.updateMicrocode = true;
  hardware.cpu.intel.updateMicrocode = true;

  nix = {
    useSandbox = true;
    buildCores = 0;  # 0 means auto-detect number of CPUs (and use all)
    trustedUsers = [ "root" "@wheel" ];

    extraOptions = ''
      # To not get caught by the '''"nix-collect-garbage -d" makes
      # "nixos-rebuild switch" unusable when nixos.org is down"''' issue:
      gc-keep-outputs = true

      # Number of seconds to wait for binary-cache to accept() our connect()
      connect-timeout = 15
    '';

    # Automatic garbage collection
    gc.automatic = true;
    gc.dates = "Mon *-*-* 00:00:00";
    gc.options = "--delete-older-than 14d";
  };

  security.wrappers = {}
    // (if (builtins.elem pkgs.wireshark config.environment.systemPackages) then {
         dumpcap = {
           # Limit access to dumpcap to root and members of the wireshark group.
           source = "${pkgs.wireshark}/bin/dumpcap";
           program = "dumpcap";
           owner = "root";
           group = "wireshark";
           setuid = true;
           setgid = false;
           permissions = "u+rx,g+x";
         };
       } else {})
    // (if (builtins.elem pkgs.smartmontools config.environment.systemPackages) then {
         smartctl = {
           # Limit access to smartctl to root and members of the munin group.
           source = "${pkgs.smartmontools}/bin/smartctl";
           program = "smartctl";
           owner = "root";
           group = "munin";
           setuid = true;
           setgid = false;
           permissions = "u+rx,g+x";
         };
       } else {});

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  nixpkgs.config = import ./nixpkgs-config.nix;

  time.timeZone = "Europe/Oslo";

  # Block advertisement domains (see
  # http://winhelp2002.mvps.org/hosts.htm)
  #environment.etc."hosts".source =
  #  pkgs.fetchurl {
  #    url = "http://winhelp2002.mvps.org/hosts.txt";
  #    sha256 = "18as5cm295yyrns4i2hzxlb1h52x68gbnb1b3yksvzqs283pvbfi";
  #  };

  # for "attic mount -o allow_other" to be shareable with samba
  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';

  environment.systemPackages = with pkgs; [
    ctags  # needed by vim (plugin)
    fzf
    moreutils
    my.git
    my.tmux
    my.vim
    tig
  ];

  fonts.fonts = with pkgs; [
    #pythonPackages.powerline  # looks ok
    powerline-fonts            # looks better
  ];

  # Make it easier to work with external scripts
  system.activationScripts.fhsCompat = ''
    fhscompat=0  # set to 1 or 0
    if [ "$fhscompat" = 1 ]; then
        echo "enabling (simple) FHS compatibility"
        mkdir -p /bin /usr/bin
        ln -sfv ${pkgs.bash}/bin/sh /bin/bash
        ln -sfv ${pkgs.perl}/bin/perl /usr/bin/perl
        ln -sfv ${pkgs.python2Full}/bin/python /usr/bin/python
        ln -sfv ${pkgs.python2Full}/bin/python /usr/bin/python2
    else
        # clean up
        find /bin /usr/bin -type l | while read file; do if [ "$file" != "/bin/sh" -a "$file" != "/usr/bin/env" ]; then rm -v "$file"; fi; done
    fi
  '';

  services = {
    openssh = {
      enable = true;
      forwardX11 = true;
      passwordAuthentication = false;
      extraConfig = ''
        AllowUsers backup git bf
        # For nix remote / distributed builds
        AllowUsers nix-remote-build

        # Doesn't work on NixOS: https://github.com/NixOS/nixpkgs/issues/18503
        ## Allow password authentication (only) from local network
        #Match Address 192.168.1.0/24
        #  PasswordAuthentication yes
        #  # End the match group so that any remaining options (up to the end
        #  # of file) applies globally
        #  Match All
      '';
    };
  };

  systemd.services."status-email@" = {
    description = "Send Status Email For Unit %i";
    path = [ "/run/wrappers" ];
    serviceConfig = {
      Type = "oneshot";
      # If running as nobody:systemd-journal the log is missing and this
      # warning is shown:
      #  Warning: Journal has been rotated since unit was started. Log output is incomplete or unavailable.
      #User = "nobody";
      #Goup = "systemd-journal";
      SyslogIdentifier = "status-email";
      ExecStart =
        let
          statusEmail = pkgs.writeScript "status-email" ''
            #!${pkgs.bash}/bin/sh
            set -e
            addr=$1
            unit=$2
            sendmail -t <<__EOF__
            To: $addr
            From: systemd@$HOSTNAME <root@$HOSTNAME>
            Subject: $unit
            Content-Transfer-Encoding: 8bit
            Content-Type: text/plain; charset=UTF-8

            $(systemctl status --full "$unit" -n80)
            __EOF__
            echo "Status mail sent to $addr for unit $unit"
          '';
        in
          # Use config.postfix.rootAlias to configure who gets root's email.
          "${statusEmail} root %i";
    };
  };

  # groups for managing permissions
  users.extraGroups = {
    plugdev = { gid = 500; };
    tracing = { gid = 501; };
    usbtmc = { gid = 502; };
    wireshark = { gid = 503; };
    usbmon = { gid = 504; };
  };
}
