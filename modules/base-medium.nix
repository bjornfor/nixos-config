{ config, lib, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ../hardware-configuration.nix
    ./base-small.nix
  ];

  hardware.sane.enable = true; # scanner support

  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
  };

  hardware.bluetooth.enable = true;

  hardware.opengl.driSupport32Bit = true;

  environment.systemPackages = with pkgs; [
    chromium
    file
    gitFull
    htop
    iw
    lshw
    ncdu
    parted
    patchelf
    pavucontrol
    pciutils
    psmisc
    tig
    unrar
    unzip
    usbutils
    vim_configurable
    wget
    which
    w3m
    xpra
  ];

  virtualisation.libvirtd.enable = true;
  virtualisation.lxc.enable = true;
  virtualisation.lxc.usernetConfig = ''
    bfo veth lxcbr0 10
  '';
  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "overlay";

  services = {
    # TODO: When mouse gets hidden, the element below mouse gets focus
    # periodically (annoying). Might try the unclutter fork (see Archlinux) or
    # xbanish.
    #unclutter.enable = true;

    fail2ban.enable = true;
    fail2ban.jails.ssh-iptables = ''
      enabled = true
    '';

    # cups, for printing documents
    printing.enable = true;
    printing.gutenprint = true; # lots of printer drivers

    xserver = {
      enable = true;
      layout = "no";
      #xkbOptions = "eurosign:e";

      # Select display manager (a.k.a. login manager)
      #displayManager.lightdm.enable = true;
      #displayManager.kdm.enable = true;
      #displayManager.slim.enable = true;
      #displayManager.auto.enable = true;
      #displayManager.auto.user = "bfo";
      displayManager.gdm.enable = true;
      displayManager.gdm.autoLogin.enable = true;
      displayManager.gdm.autoLogin.user = "bfo";

      # Select desktop environment
      desktopManager.gnome3.enable = true;
      #desktopManager.kde4.enable = true;
      #desktopManager.xfce.enable = true;

      libinput.enable = true;
    };

    locate.enable = true;

    # Provide "MODE=666" or "MODE=664 + GROUP=plugdev" for a bunch of USB
    # devices, so that we don't have to run as root.
    udev.packages = with pkgs; [ rtl-sdr saleae-logic openocd ];
    udev.extraRules = ''
      # Rigol oscilloscopes
      SUBSYSTEMS=="usb", ACTION=="add", ATTRS{idVendor}=="1ab1", ATTRS{idProduct}=="0588", MODE="0660", GROUP="usbtmc"

      # Atmel Corp. STK600 development board
      SUBSYSTEM=="usb", ATTR{idVendor}=="03eb", ATTR{idProduct}=="2106", GROUP="plugdev", MODE="0660"

      # Atmel Corp. JTAG ICE mkII
      SUBSYSTEM=="usb", ATTR{idVendor}=="03eb", ATTR{idProduct}=="2103", GROUP="plugdev", MODE="0660"

      # Atmel Corp. AVR Dragon
      SUBSYSTEM=="usb", ATTR{idVendor}=="03eb", ATTR{idProduct}=="2107", GROUP="plugdev", MODE="0660"

      # Access to /dev/bus/usb/* devices. Needed for virt-manager USB
      # redirection.
      SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0664", GROUP="wheel"
    '';

    apcupsd = {
      #enable = true;
      hooks.doshutdown = ''
        HOSTNAME=\$(${pkgs.nettools}/bin/hostname)
        printf \"Subject: apcupsd: \$HOSTNAME is shutting down\\n\" | ${pkgs.msmtp}/bin/msmtp -C /home/bfo/.msmtprc bjorn.forsman@gmail.com
      '';
      hooks.onbattery = ''
        HOSTNAME=\$(${pkgs.nettools}/bin/hostname)
        printf \"Subject: apcupsd: \$HOSTNAME is running on battery\\n\" | ${pkgs.msmtp}/bin/msmtp -C /home/bfo/.msmtprc bjorn.forsman@gmail.com
      '';
      hooks.offbattery = ''
        HOSTNAME=\$(${pkgs.nettools}/bin/hostname)
        printf \"Subject: apcupsd: \$HOSTNAME is running on mains power\\n\" | ${pkgs.msmtp}/bin/msmtp -C /home/bfo/.msmtprc bjorn.forsman@gmail.com
      '';
      configText = ''
        UPSTYPE usb
        NISIP 127.0.0.1
        BATTERYLEVEL 75
        MINUTES 10
        #TIMEOUT 10  # for debugging, shutdown after N seconds on batteries
      '';
    };

    transmission = {
      #enable = true;
      settings = {
        download-dir = "/srv/torrents/";
        incomplete-dir = "/srv/torrents/.incomplete/";
        incomplete-dir-enabled = true;
        rpc-whitelist = "127.0.0.1,192.168.1.*";
        ratio-limit = 2;
        ratio-limit-enabled = true;
        rpc-bind-address = "0.0.0.0";  # web server
      };
    };

    # TODO: Change perms on /var/lib/collectd from 700 to something more
    # permissive, at least group readable?
    # The NixOS service currently only sets perms *once*, so I've manually
    # loosened it up for now, to allow lighttpd to read RRD files.
    collectd = {
      #enable = true;
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
        LoadPlugin libvirt
        LoadPlugin load
        LoadPlugin memory
        LoadPlugin network
        LoadPlugin nfs
        LoadPlugin processes
        LoadPlugin rrdtool
        LoadPlugin sensors
        LoadPlugin tcpconns
        LoadPlugin uptime

        <Plugin "libvirt">
          Connection "qemu:///system"
        </Plugin>

        # Ignore some paths/filesystems that cause "Permission denied" spamming
        # in the log and/or are uninteresting or duplicates.
        <Plugin "df">
          MountPoint "/run/media/bfo/wd_apollo"
          MountPoint "/var/lib/docker/devicemapper"
          MountPoint "/nix/store"  # it's just a bind mount, already covered
          FSType "fuse.gvfsd-fuse"
          FSType "cgroup"
          FSType "tmpfs"
          FSType "devtmpfs"
          IgnoreSelected true
        </Plugin>

        # Output/write plugin (need at least one, if metrics are to be persisted)
        <Plugin "rrdtool">
          CacheFlush 120
          WritesPerSecond 50
        </Plugin>
      '';
    };

    samba = {
      #enable = true;
      nsswins = true;
      extraConfig = lib.mkBefore ''
        workgroup = WORKGROUP
        map to guest = Bad User

        [upload]
        path = /home/bfo/upload
        read only = no
        guest ok = yes
        force user = bfo
      '';
    };

    munin-node.enable = true;
    munin-node.extraConfig = ''
      cidr_allow 192.168.1.0/24
    '';
    munin-cron = {
      enable = true;
      hosts = ''
        [${config.networking.hostName}]
        address localhost
      '';
    };

  };

  systemd.services.helloworld = {
    description = "Hello World Loop";
    #wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "bfo";
      ExecStart = ''
        ${pkgs.stdenv.shell} -c "while true; do echo Hello World; sleep 10; done"
      '';
    };
  };
}
