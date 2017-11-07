{ config, lib, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ../hardware-configuration.nix
    ./base-small.nix
    ./munin.nix
    ./desktop-gnome3.nix
    ./virtualisation.nix
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [
    sysdig
  ];

  hardware.sane.enable = true; # scanner support

  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
  };

  hardware.bluetooth.enable = true;

  hardware.opengl.driSupport32Bit = true;

  environment.systemPackages = with pkgs; [
    apg
    arp-scan
    ascii
    bc
    borgbackup
    bridge-utils
    byobu
    chromium
    cifs_utils  # for mount.cifs, needed for cifs filesystems in systemd.mounts.
    ctags
    ddrescue
    diffstat
    dmidecode
    dos2unix
    exiv2
    file
    firefox
    gcc
    gdb
    gitFull
    gnumake
    hdparm
    htop
    iotop
    iptables
    iw
    jq
    keepass
    keepassx-community
    lm_sensors
    lshw
    lsof
    manpages # for "man 2 fork" etc.
    minicom
    mosh
    msmtp
    mutt
    ncdu
    networkmanager
    networkmanagerapplet
    nixops
    nixpkgs-lint
    nix-generate-from-cpan
    nix-prefetch-scripts
    nix-repl
    nix-serve
    nox
    ntfs3g
    owncloud-client
    p7zip
    parted
    patchelf
    pavucontrol
    perlPackages.ImageExifTool
    pciutils
    picocom
    posix_man_pages
    powertop
    psmisc
    pv
    pythonFull
    pythonPackages.demjson  # has a jsonlint command line tool (alternative: json_pp from perl)
    pythonPackages.ipython
    pythonPackages.sympy
    python2nix
    rmlint
    samba
    screen
    silver-searcher
    smartmontools
    sqlite-interactive
    sshfsFuse
    stdmanpages
    sysdig
    sysstat
    taskwarrior
    tcpdump
    tig
    torbrowser
    traceroute
    tree
    unrar
    unzip
    usbutils
    vifm
    vim_configurable
    vlc
    wget
    wgetpaste
    which
    wireshark
    w3m
    xdotool  # for keepass auto-type feature
    xpra
  ];

  networking.networkmanager.pia-vpn.enable = true;
  networking.networkmanager.pia-vpn.usernameFile = "/etc/pia-vpn.username";
  networking.networkmanager.pia-vpn.passwordFile = "/etc/pia-vpn.password";
  networking.networkmanager.pia-vpn.serverList =
    [ "denmark" "fi" "nl" "no" "sweden" "uk-london" "us-newyorkcity" ];

  programs.chromium = {
    enable = true;
    # Imperatively installed extensions will seamlessly merge with these.
    # Removing extensions here will remove them from chromium, no matter how
    # they were installed.
    extensions = [
      "cmedhionkhpnakcndndgjdbohmhepckk" # Adblock for Youtube™
      "bodncoafpihbhpfljcaofnebjkaiaiga" # appear.in screen sharing
      "iaalpfgpbocpdfblpnhhgllgbdbchmia" # Asciidoctor.js Live Preview
      "ompiailgknfdndiefoaoiligalphfdae" # chromeIPass
      "gcbommkclmclpchllfjekcdonpmejbdp" # HTTPS Everywhere
      "dbepggeogbaibhgnhhndojpepiihcmeb" # Vimium
    ];
  };
  # Apply the same programs.chromium settings to google-chrome
  environment.etc."opt/chrome".source = "/etc/chromium";

  services = {
    atd.enable = true;

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

    locate = {
      enable = true;
      # "findutils" is the default package (as per NixOS 17.03), but "mlocate"
      # has benefits:
      # 1. It (supposedly) updates its database faster.
      # 2. Its 'locate' command checks user permissions so that
      #    (a) users only see files they have access to on the filesystem and
      #    (b) indexing can run as root (without leaking file listings to
      #    unprivileged users).
      locate = pkgs.mlocate;
      localuser = null;  # needed so mlocate can run as root (TODO: improve NixOS module)
      interval = "02:15";
    };

    # for hamster-time-tracker
    dbus.packages = with pkgs; [ gnome3.gconf ];

    postfix = {
      enable = true;
      # Possibly set "domain" in machine specific configs.
      # The default "From:" address is
      #   user@${config.networking.hostName}.localdomain
      #domain = "server1.example";
      rootAlias = "bjorn.forsman@gmail.com";
      extraConfig = ''
        inet_interfaces = loopback-only
      '';
    };

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

      # Allow users in group 'usbmon' to do USB tracing, e.g. in Wireshark
      # (after 'modprobe usbmon').
      SUBSYSTEM=="usbmon", GROUP="usbmon", MODE="640"
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
