# Edit this configuration file to define what should be installed on
# the system.  Help is available in the configuration.nix(5) man page
# or the NixOS manual available on virtual console 8 (Alt+F8).

{ config, lib, pkgs, ... }:

let
  myDesktop = "mini";   # Runs a webserver, UPS daemon, ...
  myLaptop  = "nixos-laptop"; # Similar, but no webserver etc
  hostname  = myDesktop;      # Select between desktop/laptop setup

  # Select Linux version
  linuxPackages = pkgs.linuxPackages;

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

  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
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
    device = if hostname == myDesktop then
               "/dev/disk/by-id/ata-KINGSTON_SH103S3240G_50026B722A027195"
             else if hostname == myLaptop then
               "/dev/disk/by-id/ata-INTEL_SSDSA2CW160G3_CVPR106000FW160DGN" else
             throw "Missing boot.loader.grub.device setting for hostname \"${hostname}\"";
  };

  # This fixes the touchpad resoultion and 2-finger scroll on my Asus UL30A
  # laptop (and it doesn't hurt my desktop settings)
  boot.kernelModules = [ "psmouse" ];
  boot.extraModprobeConfig = " options psmouse proto=imps ";

  boot.kernelPackages = linuxPackages // {
    virtualbox = linuxPackages.virtualbox.override {
      enableExtensionPack = (hostname == myDesktop);
    };
  };
  #boot.extraModulePackages = [ linuxPackages.lttng-modules ];  # fails on linux 3.18+


  ##### Networking #####
  networking = {
    hostName = hostname;
    firewall.enable = false;
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
  users.extraUsers = {
    bfo = {
      description = "Bjørn Forsman";
      uid = 1000;
      extraGroups = [
        "adm"
        "audio"
        "dialout"
        "libvirtd"
        "networkmanager"
        "plugdev"
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


  ##### Misc stuff (shellInit, powerManagement etc.) #####
  nix = {
    useChroot = true;
    # To not get caught by the '''"nix-collect-garbage -d" makes "nixos-rebuild
    # switch" unusable when nixos.org is down"''' issue:
    extraOptions = ''
      gc-keep-outputs = true
      log-servers = http://hydra.nixos.org/log
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
    extraConfig = ''
      # Keep MODULE_DIR so modprobe doesn't forget where modules are.
      Defaults env_keep+=MODULE_DIR
    '';
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

  hardware.pulseaudio.enable = true;

  hardware.bluetooth.enable = true;

  # KDE displays a warning if this isn't enabled
  powerManagement.enable = true;

  # Hostname lookup doesn't work after system suspend.
  # Restarting nscd fixes it.
  powerManagement.resumeCommands = "systemctl restart nscd";

  environment.gnome3.packageSet = pkgs.gnome3_12;

  environment.shellAliases = {
    ".." = "cd ..";
    "..." = "cd ../..";
    "..2" = "cd ../..";
    "..3" = "cd ../../..";
    "..4" = "cd ../../../..";
  };

  environment.shellInit = ''
    #export PYTHONPATH=$PYTHONPATH:/run/current-system/sw/lib/python2.7/site-packages/
  '' + lib.optionalString (hostname == myLaptop) ''
    # "xset" makes my Asus UL30A touchpad move quite nicely.
    test -n "$DISPLAY" && xset mouse 10/4 0
  '';

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

    # Append Python site-packages directories to PYTHONPATH (for each nix profile)
    export PYTHONPATH="$(unset _tmp; for profile in $NIX_PROFILES; do _tmp="$profile/lib/python2.7/site-packages''${_tmp:+:}$_tmp"; done; echo "$PYTHONPATH''${PYTHONPATH:+:}$_tmp")"
  '';

  # Block advertisement domains (see
  # http://winhelp2002.mvps.org/hosts.htm)
  environment.etc."hosts".source =
    pkgs.fetchurl {
      url = "http://winhelp2002.mvps.org/hosts.txt";
      sha256 = "18as5cm295yyrns4i2hzxlb1h52x68gbnb1b3yksvzqs283pvbfi";
    };

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


  ##### System packages #####
  environment.systemPackages = with pkgs; [
    (callPackage ltsa {})
    (asciidoc-full.override { enableExtraPlugins = true; })
    anki  # flash card learning application
    apg
    arp-scan
    ascii
    aspell
    aspellDicts.en
    aspellDicts.nb
    attic
    babeltrace
    bc
    bind
    bmon
    bridge_utils
    chromium
    llvmPackages.clang   # for libclang, required by clang_complete.vim
    clangAnalyzer  # a.k.a. scan-build
    cmakeWithGui
    ctags
    dash
    ddrescue
    dhex
    dia
    diffstat
    dmidecode
    dos2unix
    dstat
    eagle
    eclipses.eclipse_cpp_43
    elinks
    evtest
    file
    filezilla
    firefoxWrapper
    freecad
    gcc
    gdb
    gitAndTools.qgit
    gitFull
    gnome3.dconf  # Required by virt-manager to store settings (dconf-service will be started when needed). NOTE: enabling GNOME 3 desktop auto-enables this.
    gnumake
    gource
    gparted
    gqrx
    graphviz
    gsmartcontrol
    hdparm
    htop
    iftop
    ioping
    iotop
    iptables
    irssi
    iw
    kalibrate-rtl
    #kde4.ark
    #kde4.bluedevil
    #kde4.gwenview
    #kde4.kdemultimedia  # for volume control applet (kmix), and probably lots more
    ##kde4.networkmanagement
    #kde4.okular
    lftp
    libfaketime
    libreoffice
    linssid
    linuxPackages.perf
    lshw
    lsof
    ltrace
    lttng-tools
    lynx
    manpages # for "man 2 fork" etc.
    meld
    mercurial
    minicom
    mosh
    msmtp
    mutt
    ncdu
    networkmanager
    networkmanagerapplet
    nfs-utils
    nixpkgs-lint
    nix-generate-from-cpan
    nix-prefetch-scripts
    nix-repl
    nmap_graphical
    offlineimap
    openconnect
    openocd
    openscad
    p7zip
    parted
    patchelf
    pavucontrol
    pencil
    poppler
    posix_man_pages
    powertop
    psmisc
    pthreadmanpages
    pulseview  # sigrok GUI
    pv
    pwgen
    pythonFull
    pythonPackages.demjson  # has a jsonlint command line tool (alternative: json_pp from perl)
    pythonPackages.ipython
    pythonPackages.sympy
    python2nix
    qemu
    qmmp
    #qtcreator
    remake
    remmina
    rmlint
    rtl-sdr
    saleae-logic
    samba
    screen
    sigrok-cli
    silver-searcher
    simplescreenrecorder
    (if hostname == myLaptop then
      # My laptop (Asus UL30A) has upside down webcam. Flip it back.
      let
        libv4l_i686 = callPackage_i686 <nixpkgs/pkgs/os-specific/linux/v4l-utils> { withQt4 = false; };
      in
      lib.overrideDerivation skype (attrs: {
        installPhase = attrs.installPhase +
          ''
            sed -i "2iexport LD_PRELOAD=${libv4l_i686}/lib/v4l1compat.so" "$out/bin/skype"
          '';
      })
    else
      # Other machines don't need the flip (use plain skype).
      skype
    )
    sloccount
    smartmontools
    socat
    solfege
    spice
    spotify
    sqlite-interactive
    srecord
    stdmanpages
    subversion
    surfraw
    sweethome3d.application
    taskwarrior
    tcpdump
    teamviewer
    telnet
    tig
    traceroute
    tree
    unoconv
    unrar
    unzip
    vifm
    vim_configurable
    virtmanager
    virtviewer
    vlc
    weston
    wget
    wgetpaste
    which
    wineUnstable
    winpdb
    wireshark
    wpa_supplicant
    wpa_supplicant_gui
    w3m
    xchat
    youtubeDL
  ];


  ##### Services #####
  virtualisation.libvirtd.enable = true;
  virtualisation.lxc.enable = true;
  virtualisation.lxc.usernetConfig = ''
    bfo veth lxcbr0 10
  '';
  virtualisation.docker.enable = true;
  services = {
    fail2ban.enable = true;

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
    #printing.enable = true;

    xserver = {
      enable = true;
      layout = "no";
      #xkbOptions = "eurosign:e";

      # Select display manager (a.k.a. login manager)
      #displayManager.lightdm.enable = true;
      #displayManager.kdm.enable = true;
      #displayManager.slim.enable = true;
      displayManager.auto.enable = true;
      displayManager.auto.user = "bfo";

      # Select desktop environment
      desktopManager.gnome3.enable = true;
      #desktopManager.kde4.enable = true;
      #desktopManager.xfce.enable = true;

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

    postfix = {
      enable = (hostname == myDesktop);
      domain = "bforsman.name";
      hostname = "bforsman.name";
    };

    lighttpd = {
      enable = (hostname == myDesktop);
      mod_status = true;
      mod_userdir = true;
      enableModules = [ "mod_alias" "mod_proxy" "mod_access" ];
      extraConfig = ''
        dir-listing.activate = "enable"
        alias.url += ( "/munin" => "/var/www/munin" )

        # Reverse proxy for transmission bittorrent client
        proxy.server = (
          "/transmission" => ( "transmission" => (
                               "host" => "127.0.0.1",
                               "port" => 9091
                             ) )
        )
        # Fix transmission URL corner case: get error 409 if URL is
        # /transmission/ or /transmission/web. Redirect those URLs to
        # /transmission (no trailing slash).
        url.redirect = ( "^/transmission/(web)?$" => "/transmission" )

        # Enable HTTPS
        # See documentation: http://redmine.lighttpd.net/projects/lighttpd/wiki/Docs_SSL
        $SERVER["socket"] == ":443" {
          ssl.engine = "enable"
          #ssl.pemfile = "/etc/lighttpd/certs/lighttpd.pem"  # my self-signed cert
          ssl.pemfile = "/etc/lighttpd/certs/bforsman.name.pem"  # my cert
          ssl.ca-file = "/etc/lighttpd/certs/intermediate_and_root_ca.pem"
        }

        # Block access to certain URLs if remote IP is not on LAN
        $HTTP["remoteip"] != "192.168.1.0/24" {
            $HTTP["url"] =~ "(^/transmission/.*|^/server-.*|^/munin/.*)" {
                url.access-deny = ( "" )
            }
        }
      '';
      gitweb.enable = true;
      cgit = {
        enable = true;
        configText = ''
          # HTTP endpoint for git clone is enabled by default
          #enable-http-clone=1

          # Specify clone URLs using macro expansion
          clone-url=http://${hostname}/cgit/$CGIT_REPO_URL git@${hostname}:$CGIT_REPO_URL

          # Enable 'stats' page and set big upper range
          max-stats=year

          # Allow download of tar.gz, tar.bz2, tar.xz and zip-files
          snapshots=tar.gz tar.bz2 tar.xz zip

          # Enable caching of up to 1000 output entries
          cache-size=1000

          # about-formatting.sh is impure (doesn't work)
          #about-filter=${pkgs.cgit}/lib/cgit/filters/about-formatting.sh
          # Add simple plain-text filter
          about-filter=${pkgs.writeScript "cgit-about-filter.sh"
            ''
              #!${pkgs.stdenv.shell}
              echo "<pre>"
              ${pkgs.coreutils}/bin/cat
              echo "</pre>"
            ''
          }

          # Search for these files in the root of the default branch of
          # repositories for coming up with the about page:
          readme=:README.asciidoc
          readme=:README.txt
          readme=:README
          readme=:INSTALL.asciidoc
          readme=:INSTALL.txt
          readme=:INSTALL

          # scan-path must be last so that earlier settings take effect when
          # scanning
          scan-path=/srv/git
        '';
      };
    };

    apcupsd = {
      enable = (hostname == myDesktop);
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
      enable = (hostname == myDesktop);
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
      '' else "")
      + (if hostname == myDesktop then ''
        [media]
        path = /data/media
        read only = yes
        guest ok = yes

        [pictures]
        path = /data/pictures/
        read only = yes
        guest ok = yes

        [programs]
        path = /data/programs/
        read only = yes
        guest ok = yes

        [backups]
        path = /media/3tb/backups/
        read only = yes
        guest ok = yes
      '' else "");
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
      '' + lib.optionalString (hostname == myLaptop) ''
        [${myDesktop}]
        address ${myDesktop}.local
      '' + lib.optionalString (hostname == myDesktop) ''
        [${myLaptop}]
        address ${myLaptop}.local
      '';
    };

    virtualboxHost.enable = (hostname == myDesktop);
    virtualboxHost.enableHardening = true;

    mysql = {
      enable = (hostname == myDesktop);
      package = pkgs.mysql;
      extraOptions = ''
        # This is added in the [mysqld] section in my.cnf
      '';
    };

    nfs.server = {
      enable = (hostname == myDesktop);
      exports = ''
        /nix/ 192.168.1.0/24(ro)
      '';
    };

    ntopng = {
      enable = true;
      extraConfig = "--disable-login";
    };
  };


  ##### Custom services #####
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

  systemd.services.my-backup = {
    enable = hostname == myDesktop;
    description = "My Backup";
    startAt = "*-*-* 01:15:00";  # see systemd.time(7)
    path = with pkgs; [ bash rsync openssh utillinux gawk nettools time ];
    serviceConfig.ExecStart = /home/bfo/bin/backup.sh;
  };

}
