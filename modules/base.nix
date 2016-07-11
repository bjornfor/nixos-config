{ config, lib, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ../hardware-configuration.nix
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

  # Select Linux version
  boot.kernelPackages = pkgs.linuxPackages;
  boot.extraModulePackages = [ config.boot.kernelPackages.lttng-modules ];

  networking = {
    firewall.enable = false;
    networkmanager.enable = true;
  };

  users.extraUsers = {
    bfo = {
      description = "Bjørn Forsman";
      uid = 1000;
      extraGroups = [
        "adm"
        "audio"
        "cdrom"
        "dialout"
        "docker"
        "libvirtd"
        "networkmanager"
        "plugdev"
        "scanner"
        "systemd-journal"
        "tracing"
        "transmission"
        "tty"
        "usbtmc"
        "vboxusers"
        "video"
        "wheel"
        "wireshark"
      ];
      isNormalUser = true;
      initialPassword = "initialpw";
      # Subordinate user ids that user is allowed to use. They are set into
      # /etc/subuid and are used by newuidmap for user namespaces. (Needed for
      # LXC.)
      subUidRanges = [
        { startUid = 100000; count = 65536; }
      ];
      subGidRanges = [
        { startGid = 100000; count = 65536; }
      ];

    };
  };

  users.extraGroups = {
    plugdev = { gid = 500; };
    tracing = { gid = 501; };
    usbtmc = { gid = 502; };
    wireshark = { gid = 503; };
  };

  nix = {
    useChroot = true;
    # To not get caught by the '''"nix-collect-garbage -d" makes "nixos-rebuild
    # switch" unusable when nixos.org is down"''' issue:
    extraOptions = ''
      gc-keep-outputs = true
      log-servers = http://hydra.nixos.org/log
      build-cores = 0  # 0 means auto-detect number of CPUs (and use all)
    '';
  };

  # Select internationalisation properties.
  i18n.consoleKeyMap = "qwerty/no";

  security.setuidOwners = [
    { # Limit access to dumpcap to root and members of the wireshark group.
      source = "${pkgs.wireshark}/bin/dumpcap";
      program = "dumpcap";
      owner = "root";
      group = "wireshark";
      setuid = true;
      setgid = false;
      permissions = "u+rx,g+x";
    }
    { # Limit access to smartctl to root and members of the munin group.
      source = "${pkgs.smartmontools}/bin/smartctl";
      program = "smartctl";
      owner = "root";
      group = "munin";
      setuid = true;
      setgid = false;
      permissions = "u+rx,g+x";
    }
  ];

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  security.pam.loginLimits = [
    { domain = "@audio"; type = "-"; item = "rtprio"; value = "75"; }
    { domain = "@audio"; type = "-"; item = "memlock"; value = "500000"; }
  ];

  # Override similar to ~/.nixpkgs/config.nix (see "man configuration.nix" and
  # search for "nixpkgs.config"). Also, make sure to read
  # http://nixos.org/nixos/manual/#sec-customising-packages
  nixpkgs.config = {
    allowUnfree = true;  # allow proprietary packages
    firefox.enableAdobeFlash = true;
    chromium.enablePepperFlash = true;
    packageOverrides = pkgs: {
      #qtcreator = pkgs.qtcreator.override { qt48 = pkgs.qt48Full; };
      #qemu = pkgs.qemu.override { spiceSupport = true; };
    };
  };

  time.timeZone = "Europe/Oslo";

  hardware.sane.enable = true; # scanner support

  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
  };

  hardware.bluetooth.enable = true;

  hardware.opengl.driSupport32Bit = true;

  # KDE displays a warning if this isn't enabled
  powerManagement.enable = true;

  environment.shellAliases = {
    ".." = "cd ..";
    "..." = "cd ../..";
    "..2" = "cd ../..";
    "..3" = "cd ../../..";
    "..4" = "cd ../../../..";
  };

  environment.interactiveShellInit = ''
    # A nix query helper function
    nq()
    {
      case "$@" in
        -h|--help|"")
          printf "nq: A tiny nix-env wrapper to search for packages in package name, attribute name and description fields\n";
          printf "\nUsage: nq <case insensitive regexp>\n";
          return;;
      esac
      nix-env -qaP --description \* | grep -i "$@"
    }

    export HISTCONTROL=ignoreboth   # ignorespace + ignoredups
    export HISTSIZE=1000000         # big big history
    export HISTFILESIZE=$HISTSIZE
    shopt -s histappend             # append to history, don't overwrite it
  '';

  environment.profileRelativeEnvVars = {
    GRC_BLOCKS_PATH = [ "/share/gnuradio/grc/blocks" ];
    PYTHONPATH = [ "/lib/python2.7/site-packages" ];
  };

  environment.sessionVariables = {
    NIX_AUTO_INSTALL = "1";
  };

  # Block advertisement domains (see
  # http://winhelp2002.mvps.org/hosts.htm)
  environment.etc."hosts".source =
    pkgs.fetchurl {
      url = "http://winhelp2002.mvps.org/hosts.txt";
      sha256 = "18as5cm295yyrns4i2hzxlb1h52x68gbnb1b3yksvzqs283pvbfi";
    };

  # for "attic mount -o allow_other" to be shareable with samba
  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';

  # Make it easier to work with external scripts
  system.activationScripts.fhsCompat = ''
    fhscompat=0  # set to 1 or 0
    if [ "$fhscompat" = 1 ]; then
        echo "enabling (simple) FHS compatibility"
        mkdir -p /bin /usr/bin
        ln -sfv ${pkgs.bash}/bin/sh /bin/bash
        ln -sfv ${pkgs.perl}/bin/perl /usr/bin/perl
        ln -sfv ${pkgs.python27Full}/bin/python /usr/bin/python
    else
        # clean up
        find /bin /usr/bin -type l | while read file; do if [ "$file" != "/bin/sh" -a "$file" != "/usr/bin/env" ]; then rm -v "$file"; fi; done
    fi
  '';

  # Show git info in bash prompt and display a colorful hostname if using ssh.
  programs.bash.promptInit = ''
    export GIT_PS1_SHOWDIRTYSTATE=1
    source ${pkgs.gitAndTools.gitFull}/share/git/contrib/completion/git-prompt.sh

    __prompt_color="1;32m"
    # Alternate color for hostname if the generated color clashes with prompt color
    __alternate_color="1;33m"
    __hostnamecolor="$__prompt_color"
    # If logged in with ssh, pick a color derived from hostname
    if [ -n "$SSH_CLIENT" ]; then
      __hostnamecolor="1;$(${pkgs.nettools}/bin/hostname | od | tr ' ' '\n' | ${pkgs.gawk}/bin/awk '{total = total + $1}END{print 30 + (total % 6)}')m"
      # Fixup color clash
      if [ "$__hostnamecolor" = "$__prompt_color" ]; then
        __hostnamecolor="$__alternate_color"
      fi
    fi

    __red="1;31m"

    PS1='\n$(ret=$?; test $ret -ne 0 && printf "\[\e[$__red\]$ret\[\e[0m\] ")\[\e[$__prompt_color\]\u@\[\e[$__hostnamecolor\]\h \[\e[$__prompt_color\]\w$(__git_ps1 " [git:%s]")\[\e[0m\]\n$ '
  '';

  programs.bash.enableCompletion = true;

  environment.systemPackages = with pkgs; [
    chromium
    file
    gitFull
    htop
    iw
    lshw
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

  #virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableHardening = true;

  services = {
    # TODO: When mouse gets hidden, the element below mouse gets focus
    # periodically (annoying). Might try the unclutter fork (see Archlinux) or
    # xbanish.
    #unclutter.enable = true;

    fail2ban.enable = true;
    fail2ban.jails.ssh-iptables = ''
      enabled = true
    '';

    openssh.enable = true;
    openssh.passwordAuthentication = false;
    openssh.extraConfig = ''
      AllowUsers bfo

      # Allow password authentication (only) from local network
      Match Address 192.168.1.0/24
        PasswordAuthentication yes
        # End the match group so that any remaining options (up to the end
        # of file) applies globally
        Match All
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

    # Enable avahi/mdns
    avahi = {
      enable = true;
      nssmdns = true;
      publish.enable = true;
      publish.addresses = true;
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

  systemd.services.lttng-sessiond = {
    description = "LTTng Session Daemon";
    wantedBy = [ "multi-user.target" ];
    environment.MODULE_DIR = config.environment.variables.MODULE_DIR;
    serviceConfig = {
      ExecStart = "${pkgs.lttngTools}/bin/lttng-sessiond";
    };
  };
}
