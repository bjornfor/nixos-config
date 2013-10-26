# Edit this configuration file to define what should be installed on
# the system.  Help is available in the configuration.nix(5) man page
# or the NixOS manual available on virtual console 8 (Alt+F8).

{ config, pkgs, ... }:

let
  myDesktop = "mini-nixos";   # Runs a webserver, UPS daemon, ...
  myLaptop  = "nixos-laptop"; # Similar, but no webserver etc
  hostname  = myDesktop;      # Select between desktop/laptop setup

  # Select Linux version
  #
  # Black screen issue on my Asus UL30A laptop:
  # - 3.2.44 works
  # - 3.2.45 is broken (but works if "nomodeset" is on the kernel command line
  # - 3.2.51 works
  # - 3.4.x works, current default on NixOS
  # - 3.9.x works
  linuxPackages = pkgs.linuxPackages;

  # This is a copy of the nixpkgs openconnect derivation (only the version number is changed)
  # Turns out that 4.x and 5.x is incompatible with my work VPN.
  # TODO: Use override instead of copy/paste?
  openconnect3x = { stdenv, fetchurl, pkgconfig, vpnc, openssl, libxml2 }:
    stdenv.mkDerivation rec {
      name = "openconnect-3.18";

      src = fetchurl {
        urls = [
          "ftp://ftp.infradead.org/pub/openconnect/${name}.tar.gz"
        ];
        #sha256 = "18y72hrpxpiv6r9ps3yp5128aicrswdc8cx8gzx4sfkbgrvabz8y"; # 3.17
        sha256 = "1wkszj6cqaqqmfinbjsg40l0p46agq26yh1ps8lln3wfbnkd5fbd"; # 3.18
      };

      preConfigure = ''
          export PKG_CONFIG=${pkgconfig}/bin/pkg-config
          export LIBXML2_CFLAGS="-I ${libxml2}/include/libxml2"
          export LIBXML2_LIBS="-L${libxml2}/lib -lxml2"
        '';

      configureFlags = [
        "--with-vpnc-script=${vpnc}/etc/vpnc/vpnc-script"
        "--disable-nls"
        "--without-openssl-version-check"
      ];

      propagatedBuildInputs = [ vpnc openssl libxml2 ];
    };

    ltsa = { stdenv, fetchurl, unzip, jre }:
      stdenv.mkDerivation rec {
        name = "ltsa-3.0";

        src = fetchurl {
          # The archive is unfortunately unversioned
          url = "http://www.doc.ic.ac.uk/~jnm/book/ltsa/ltsatool.zip";
          sha256 = "0ilhzr2m0k2gas2sr9l5zvw0i2xk6qznx3pllhcy28mfyb299n4y";
        };

        buildInputs = [ unzip ];

        phases = [ "installPhase" ];

        installPhase = ''
          unzip "$src"

          mkdir -p "$out/bin"
          mkdir -p "$out/lib"
          mkdir -p "$out/share/ltsa"

          cd ltsatool
          cp *.jar "$out/lib"
          cp *.txt "$out/share/ltsa"
          cp -r Chapter_examples/ "$out/share/ltsa"

          cat > "$out/bin/ltsa" << EOF
          #!${stdenv.shell}
          exec ${jre}/bin/java -jar "$out/lib/ltsa.jar" "\$@"
          EOF

          chmod +x "$out/bin/ltsa"
        '';

        meta = with stdenv.lib; {
          description = "Verification tool for concurrent systems";
          longDescription = ''
            LTSA (Labelled Transition System Analyser) mechanically checks that
            the specification of a concurrent system satisfies the properties
            required of its behaviour. In addition, LTSA supports specification
            animation to facilitate interactive exploration of system
            behaviour.

            A system in LTSA is modelled as a set of interacting finite state
            machines. The properties required of the system are also modelled
            as state machines. LTSA performs compositional reachability
            analysis to exhaustively search for violations of the desired
            properties.
          '';
          homepage = http://www.doc.ic.ac.uk/ltsa/;
          license = "unknown";
        };
      };

in
{

  require = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # VirtualBox. WARNING: virtualbox is built with --disable-hardening (a
    # security issue). That's why it isn't as easy to enable (you shouldn't use
    # it!).
    <nixos/modules/programs/virtualbox.nix>
  ];


  ##### Filesystems, bootloader and kernel modules #####
  fileSystems = if hostname == myDesktop then {
    "/".device = "/dev/disk/by-label/240gb";
    "/data".device = "/dev/disk/by-label/1.5tb";
    # My backup disk:
    "/media/3tb" = { device = "/dev/disk/by-label/3tb"; options="ro"; };
  } else if hostname == myLaptop then {
    "/".device = "/dev/disk/by-label/nixos-ssd";
  } else throw "Missing fileSystems settings for hostname \"${hostname}\"";

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
    device = if hostname == myDesktop then "/dev/disk/by-label/240gb" else
             if hostname == myLaptop  then "/dev/disk/by-label/nixos-ssd" else
             throw "Missing boot.loader.grub.device setting for hostname \"${hostname}\"";
  };

  # This fixes the touchpad resoultion and 2-finger scroll on my Asus UL30A
  # laptop (and it doesn't hurt my desktop settings)
  boot.kernelModules = [ "psmouse" ];
  boot.extraModprobeConfig = " options psmouse proto=imps ";

  boot.kernelPackages = linuxPackages // {
    virtualbox = linuxPackages.virtualbox.override { enableExtensionPack = true; };
  };
  boot.extraModulePackages = [ linuxPackages.lttngModules ];


  ##### Networking #####
  networking = {
    hostName = hostname;
    networkmanager.enable = true;
    #networkmanager.packages = [ pkgs.networkmanager_pptp ];

    # Associate with wireless network:
    # iw dev <devname> connect [-w] <SSID> [<freq in MHz>] [<bssid>] [key 0:abcde d:1:6162636465]
    #                Join the network with the given SSID (and frequency, BSSID).
    #                                With -w, wait for the connect to finish or fail.
    #
    # wicd allows us to automatically associate with a network (wpa_supplicant
    # only does the authentication). Without wicd we would have had to run
    # "iwconfig wlan0 essid <your_ssid>" to associate with network. Run wicd-gtk
    # for configuration (find your network and check the "Automatically
    # connect..." button.
    #wicd.enable = true;

    # Enable wpa_supplicant daemon. It needs to be configured: run
    # "wpa_passphrase <ssid> <password>" and copy the result to
    # /etc/wpa_supplicant.conf. Multiple network={} directives can be in that
    # file.
    #wireless.enable = true; # XXX: THIS IS THE ONE I COMMENTED OUT
  };


  ##### Users #####
  #users.mutableUsers = false;
  users.extraUsers = {
    bfo = {
      #password = "changeme";
      createHome = true;
      description = "Bjørn Forsman";
      uid = 1000;
      extraGroups = [
        "wheel" "transmission" "networkmanager" "audio" "video" "tty" "adm"
        "dialout" "systemd-journal" "vboxusers" "plugdev" "libvirtd" "tracing"
      ];
      group = "users";
      home = "/home/bfo";
      isSystemUser = false;
      useDefaultShell = true; # default is false => .../bin/nologin
    };
  };

  users.extraGroups = {
    plugdev = {};
  };


  ##### Misc stuff (shellInit, powerManagement etc.) #####
  nix = {
    #useChroot = true;
    # To not get caught by the '''"nix-collect-garbage -d" makes "nixos-rebuild
    # switch" unusable when nixos.org is down"''' issue:
    extraOptions = ''
      gc-keep-outputs = true
    '';
  };

  # Select internationalisation properties.
  i18n.consoleKeyMap = "no";

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Override similar to ~/.nixpkgs/config.nix (see "man configuration.nix" and
  # search for "nixpkgs.config"). Also, make sure to read
  # http://nixos.org/nixos/manual/#sec-customising-packages
  nixpkgs.config = {
    packageOverrides = pkgs: {
      #qtcreator = pkgs.qtcreator.override { qt48 = pkgs.qt48Full; };
      #qemu = pkgs.qemu.override { spiceSupport = true; };
    };
  };

  time.timeZone = "Europe/Oslo";

  hardware.pulseaudio.enable = true;

  # KDE displays a warning if this isn't enabled
  powerManagement.enable = true;

  # Hostname lookup doesn't work after system suspend.
  # Restarting nscd fixes it.
  powerManagement.resumeCommands = "systemctl restart nscd";

  # Shell script code called during login shell initialization
  # "xset" makes my Asus UL30A touchpad move quite nicely.
  environment.shellInit = ''
    ${if hostname == myLaptop then "xset mouse 10/4 0" else ""}

    #export PYTHONPATH=$PYTHONPATH:/run/current-system/sw/lib/python2.7/site-packages/
  '';

  # Show git info in bash prompt. This is (mostly) the default NixOS prompt plus
  # $(__git_ps1 " [git::%s]")
  programs.bash.promptInit = ''
    export GIT_PS1_SHOWDIRTYSTATE=1
    source ${pkgs.gitAndTools.gitFull}/share/git/contrib/completion/git-prompt.sh
    PROMPT_COLOR="1;31m"
    let $UID && PROMPT_COLOR="1;32m"
    PS1='\[\033[$PROMPT_COLOR\][\u@\h:\w$(__git_ps1 " [git::%s]")]\\$\[\033[0m\] '
    if test "$TERM" = "xterm"; then
      PS1="\[\033]2;\h:\u:\w\007\]$PS1"
    fi
  '';

  programs.bash.enableCompletion = true;


  ##### System packages #####
  environment.systemPackages = with pkgs; [
    (callPackage openconnect3x {})
    (callPackage ltsa {})
    (asciidocFull.override {
      enableDitaaFilter = true;
      enableMscgenFilter = true;
      enableDiagFilter = true;
      enableQrcodeFilter = true;
      enableMatplotlibFilter = true;
      enableAafigureFilter = true;
      enableDeckjsBackend = true;
      enableOdfBackend = true;
    })
    aspell
    aspellDicts.en
    aspellDicts.nb
    bmon
    chromiumWrapper
    clangUnwrapped   # for libclang, required by clang_complete.vim
    cmake
    ctags
    dmidecode
    dstat
    eagle
    eclipses.eclipse_cpp_42
    evtest
    file
    firefoxWrapper
    gcc
    gitFull
    gnumake
    gource
    graphviz
    hdparm
    htop
    iftop
    iotop
    iptables
    iw
    kde4.ark
    kde4.gwenview
    kde4.kdemultimedia  # for volume control applet (kmix), and probably lots more
    #kde4.networkmanagement
    kde4.okular
    libreoffice
    lshw
    lsof
    manpages # for "man 2 fork" etc.
    mercurial
    minicom
    mosh
    msmtp
    ncdu
    networkmanager
    networkmanagerapplet
    nfsUtils
    nixpkgs-lint
    nmap
    openocd
    openscad
    parted
    pavucontrol
    powertop
    psmisc
    pythonFull
    pythonPackages.demjson  # has a jsonlint command line tool (alternative: json_pp from perl)
    pythonPackages.ipython
    qemu
    #qemu_kvm   # qemu-kvm has been merged into qemu (use "qemu-system-x86_64 -enable-kvm")
    qmmp
    #qtcreator
    rmlint
    rubyLibs.taskjuggler
    saleaeLogic
    screen
    skype
    sloccount
    spice
    sqliteInteractive
    subversion
    telnet
    tig
    tree
    unoconv
    unzip
    vim_configurable
    virtmanager
    vlc
    #weston   # broken in master, pull #649 makes it build
    wget
    wgetpaste
    wpa_supplicant
    wpa_supplicant_gui
    xchat
  ];


  ##### Services #####
  virtualisation.libvirtd.enable = true;
  services = {
    openssh.enable = true;

    # cups, for printing documents
    #printing.enable = true;

    xserver = {
      enable = true;
      layout = "no";
      #xkbOptions = "eurosign:e";

      # Enable the KDE Desktop Environment.
      displayManager.kdm.enable = true;
      desktopManager.kde4.enable = true;
      # or the XFCE desktop environment
      #displayManager.slim.enable = true;
      #desktopManager.xfce.enable = true;
      #desktopManager.razorqt.enable = true;

      # BEGIN JUST_FOR_BUILD_VM: this is just for nixos-rebuild build-vm
      # Auto-login as root.
      #displayManager.kdm.extraConfig = ''
      #  [X-*-Core]
      #  AllowRootLogin=true
      #  AutoLoginEnable=true
      #  AutoLoginUser=root
      #  AutoLoginPass=""
      #'';
      ## END JUST_FOR_BUILD_VM

      # Needed for the touchpad on my Asus UL30A laptop (this was broken for
      # quite some time but started working again when I upgraded to NixOS
      # 0.2pre4476_a5e4432-b076ab9)
      multitouch.enable = true;

      # This also works, but the mouse has low resolution and accelsettings seems
      # to be ignored (use 'synclient' to read/write settings).
      synaptics = {
        #enable = true;
        twoFingerScroll = true;
        maxSpeed = "5.0";
        accelFactor = "0.001";
      };
    };
  
    # Enable avahi/mdns
    avahi = { enable = true; nssmdns = true; };
  
    locate.enable = true;

    cron.mailto = "root";
    cron.systemCronJobs = pkgs.lib.optionals (hostname == myDesktop) [
      # minute hour day-of-month month day-of-week user command
      " 15     01   *            *     *           root /home/bfo/bin/backup.sh > /tmp/backup.log 2>&1"
    ];

    udev.extraRules = ''
      # udev rules to let users in group "plugdev" access development tools

      # Atmel Corp. STK600 development board
      SUBSYSTEM=="usb", ATTR{idVendor}=="03eb", ATTR{idProduct}=="2106", GROUP="plugdev", MODE="0660"
      
      # Atmel Corp. JTAG ICE mkII
      SUBSYSTEM=="usb", ATTR{idVendor}=="03eb", ATTR{idProduct}=="2103", GROUP="plugdev", MODE="0660"
      
      # TinCanTools Flyswatter 2
      SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6010", GROUP="plugdev", MODE="0660"
      
      # Amontec JTAGkey2
      SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="cff8", GROUP="plugdev", MODE="0660"
      
      # STMicroelectronics ST-LINK/V2
      SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="3748", GROUP="plugdev", MODE="0660"
      
      # Saleae Logic Analyzer
      SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0925", ATTR{idProduct}=="3881", GROUP="plugdev", MODE="0660"
      SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="21a9", ATTR{idProduct}=="1001", GROUP="plugdev", MODE="0660"
    '';

    lighttpd = {
      enable = (hostname == myDesktop);
      mod_status = true;
      mod_userdir = true;
      extraConfig = ''
        dir-listing.activate = "enable"
      '';
      gitweb.enable = true;
      cgit = {
        enable = true;
        configText = ''
          cache-size=1000
          scan-path=/srv/git
        '';
      };
    };

    apcupsd = {
      enable = (hostname == myDesktop);
      hooks.doshutdown = ''
        HOSTNAME=`${pkgs.nettools}/bin/hostname`
        printf \"Subject: apcupsd: $HOSTNAME is shutting down\\n\" | ${pkgs.msmtp}/bin/msmtp -C /home/bfo/.msmtprc bjorn.forsman@gmail.com
      '';
      hooks.onbattery = ''
        HOSTNAME=`${pkgs.nettools}/bin/hostname`
        printf \"Subject: apcupsd: $HOSTNAME is running on battery\\n\" | ${pkgs.msmtp}/bin/msmtp -C /home/bfo/.msmtprc bjorn.forsman@gmail.com
      '';
      hooks.offbattery = ''
        HOSTNAME=`${pkgs.nettools}/bin/hostname`
        printf \"Subject: apcupsd: $HOSTNAME is running on mains power\\n\" | ${pkgs.msmtp}/bin/msmtp -C /home/bfo/.msmtprc bjorn.forsman@gmail.com
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
      enable = (hostname == myDesktop);
      settings = {
        download-dir = "/srv/torrents/";
        incomplete-dir = "/srv/torrents/.incomplete/";
        incomplete-dir-enabled = true;
        rpc-whitelist = "127.0.0.1,192.168.*.*";
        ratio-limit = 2;
        ratio-limit-enabled = true;
        umask = 2;
      };
    };
  
    samba = {
      enable = true;
      nsswins = true;
      extraConfig = ''
        workgroup = WORKGROUP
        map to guest = Bad User

        [upload]
        path = /home/bfo/upload
        read only = no
        guest ok = yes
        force user = bfo
      ''
      + (if config.services.transmission.enable then ''
        [torrents]
        path = /srv/torrents
        read only = no
        guest ok = yes
        force user = transmission
      '' else "");
  
    };
  
    munin-node.enable = true;
    munin-cron = {
      enable = true;
      hosts = ''
        [${config.networking.hostName}]
        address localhost
      '';
    };

    mysql = {
      enable = (hostname == myDesktop);
      extraOptions = ''
        # This is added in the [mysqld] section in my.cnf
      '';
    };

    vsftpd = {
      enable = (hostname == myDesktop);
      #anonymousUploadEnable = true;
      #anonymousUser = true;
      #anonymousMkdirEnable = true;
      #localUsers = true;
      #writeEnable = true;
    };
  };


  ##### Custom services #####
  systemd.services.helloworld = {
    description = "Hello World Loop";
    #wantedBy = ["multi-user.target"];
    serviceConfig = {
      User = "bfo";
      ExecStart = ''
        ${pkgs.stdenv.shell} -c "while true; do echo Hello World; sleep 10; done"
      '';
    };
  };
}
