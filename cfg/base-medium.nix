{ config, lib, pkgs, ... }:

{
  imports = [
    ./base-small.nix
    ./munin.nix
    ./desktop-gnome3.nix
    ./dictionary.nix
    ./postfix.nix
    ./syncthing.nix
    ./virtualisation.nix
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [
    sysdig
  ];

  hardware.sane.enable = true; # scanner support

  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
    daemon.config = {
      flat-volumes = "no";
    };
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
    chromium
    cifs_utils  # for mount.cifs, needed for cifs filesystems in systemd.mounts.
    cquery
    ddrescue
    diffstat
    dmidecode
    dos2unix
    exfat
    exiftool
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
    keepassx-community
    lm_sensors
    lshw
    lsof
    manpages # for "man 2 fork" etc.
    minicom
    mosh
    msmtp
    mutt
    my.nix-check-before-push
    my.custom-desktop-entries
    ncdu
    nethogs
    networkmanager
    networkmanagerapplet
    nixops
    nixpkgs-lint
    nix-bash-completions
    nix-generate-from-cpan
    nix-prefetch-scripts
    nix-review
    nix-serve
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
    ripgrep
    rmlint
    samba
    silver-searcher
    smartmontools
    sqlite-interactive
    sshfsFuse
    sshuttle
    stdmanpages
    sysdig
    sysstat
    taskwarrior
    tcpdump
    tmuxp
    torbrowser
    traceroute
    tree
    unrar
    unzip
    usbutils
    vbindiff
    vifm
    vlc
    wget
    wgetpaste
    which
    wireshark
    w3m
    xpra
    yubico-piv-tool
    yubikey-personalization
    yubikey-personalization-gui
  ]
  # nix-repl was replaced by the built-in "nix repl" from nix in nixos-18.09.
  ++ (lib.optional (lib.versionOlder (lib.version or lib.nixpkgsVersion) "18.09") nix-repl);

  networking.networkmanager.pia-vpn.enable = true;
  networking.networkmanager.pia-vpn.usernameFile = "/etc/pia-vpn.username";
  networking.networkmanager.pia-vpn.passwordFile = "/etc/pia-vpn.password";
  networking.networkmanager.pia-vpn.serverList =
    [ "denmark" "fi" "nl" "no" "sweden" "uk-london" "us-newyorkcity" ];

  programs.adb.enable = true;

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
    printing.drivers = with pkgs; [ gutenprint ];

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
    dbus.packages = with pkgs; [ gnome2.GConf ];

    # Provide "MODE=666" or "MODE=664 + GROUP=plugdev" for a bunch of USB
    # devices, so that we don't have to run as root.
    udev.packages = with pkgs; [
      saleae-logic openocd libu2f-host yubikey-personalization
    ];
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

    samba = {
      #enable = true;
      nsswins = true;
      extraConfig = lib.mkBefore ''
        workgroup = WORKGROUP
        map to guest = Bad User

        [upload]
        path = /home/bf/upload
        read only = no
        guest ok = yes
        force user = bf
      '';
    };

  };
}
