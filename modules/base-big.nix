{ config, lib, pkgs, ... }:

{
  imports = [
    ./base-medium.nix
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [
    lttng-modules
  ];

  environment.systemPackages = with pkgs; [
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
    bridge-utils
    llvmPackages.clang   # for libclang, required by clang_complete.vim
    clangAnalyzer  # a.k.a. scan-build
    cmakeWithGui
    ctags
    dash
    ddrescue
    dhex
    dia
    diffstat
    dos2unix
    dstat
    eagle
    (eclipses.eclipseWithPlugins {
      eclipse = eclipses.eclipse-cpp-45;
      jvmArgs = [ "-Xmx2048m" ];
      plugins = with eclipses.plugins;
        [ cdt gnuarmeclipse ];
    })
    elinks
    evtest
    exiv2
    filezilla
    firefoxWrapper
    freecad
    gcc
    gdb
    gitAndTools.qgit
    gnome3.dconf  # Required by virt-manager to store settings (dconf-service will be started when needed). NOTE: enabling GNOME 3 desktop auto-enables this.
    gnumake
    gource
    gparted
    gqrx
    graphviz
    gsmartcontrol
    hdparm
    hexchat
    iftop
    ioping
    iotop
    iptables
    irssi
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
    ltsa
    config.boot.kernelPackages.perf
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
    networkmanager
    networkmanagerapplet
    nfs-utils
    nixpkgs-lint
    nix-generate-from-cpan
    nix-prefetch-scripts
    nix-repl
    ntfs3g
    nmap_graphical
    offlineimap
    openconnect
    openocd
    openscad
    p7zip
    #pencil # https://github.com/prikhi/pencil/issues/840
    picocom
    (pidgin-with-plugins.override { plugins = [ pidginsipe ]; })
    poppler
    posix_man_pages
    powertop
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
    shotwell
    sigrok-cli
    silver-searcher
    simplescreenrecorder
    skype
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
    taskwarrior  # causes grep help text to be printed each time a new terminal is started (bash completion script is buggy)
    tcpdump
    #teamviewer  # changes hash all the time
    telnet
    traceroute
    tree
    unoconv
    vifm
    virtmanager
    virtviewer
    vlc
    weston
    wgetpaste
    wineUnstable
    winpdb
    wirelesstools
    wireshark
    wpa_supplicant
    wpa_supplicant_gui
    youtube-dl
  ];

  systemd.services.lttng-sessiond = {
    description = "LTTng Session Daemon";
    wantedBy = [ "multi-user.target" ];
    environment.MODULE_DIR = "/run/current-system/kernel-modules/lib/modules";
    serviceConfig = {
      ExecStart = "${pkgs.lttngTools}/bin/lttng-sessiond";
    };
  };
}
