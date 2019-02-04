{ config, lib, pkgs, ... }:

{
  imports = [
    ./base-small.nix
    ./munin.nix
    ./desktop-gnome3.nix
    ./dictionary.nix
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
    exfat
    exiftool
    exiv2
    file
    firefox
    fzf
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
    nethogs
    networkmanager
    networkmanagerapplet
    nixops
    nixpkgs-lint
    nix-bash-completions
    nix-generate-from-cpan
    nix-prefetch-scripts
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
    ripgrep
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
    tmux
    torbrowser
    traceroute
    tree
    unrar
    unzip
    usbutils
    vbindiff
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
  # Apply the same programs.chromium settings to google-chrome
  environment.etc =
    if lib.versionOlder (lib.version or lib.nixpkgsVersion) "18.03"
    then { "opt/chrome".source = "/etc/chromium"; }
    else {}; # NixOS 18.03 has this built-in.

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

    postfix = {
      enable = true;
      # Possibly set "domain" in machine specific configs.
      # The default "From:" address is
      #   user@${config.networking.hostName}.localdomain
      #domain = "server1.example";
      rootAlias = "bjorn.forsman@gmail.com";
      extraConfig = ''
        inet_interfaces = loopback-only

        # Postfix (or my system) seems to prefer ipv6 now, but that breaks on
        # my network:
        #
        #   connect to gmail-smtp-in.l.google.com[2a00:1450:4010:c09::1b]:25: Network is unreachable
        #
        # So let's force ipv4.
        smtp_address_preference = ipv4
      '';
    };

    syncthing = {
      enable = true;
      group = "syncthing"; # NixOS defaults to "nogroup" (should be fixed)
    };

    # Provide "MODE=666" or "MODE=664 + GROUP=plugdev" for a bunch of USB
    # devices, so that we don't have to run as root.
    udev.packages = with pkgs; [
      rtl-sdr saleae-logic openocd libu2f-host yubikey-personalization
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

  # Undo the 700 perms syncthing sets on /var/lib/syncthing on startup. Without
  # this the ACL entries for my user stop working.
  # See
  #  https://github.com/syncthing/syncthing/issues/3434
  #  https://github.com/NixOS/nixpkgs/issues/47513
  systemd.services.syncthing.postStart = lib.mkForce ''
    sleep 10
    chmod g+rx "${config.services.syncthing.dataDir}"
  '';

  # Enable debug trace to spot permission errors.
  #systemd.services.syncthing.environment.STTRACE = "scanner";
}
