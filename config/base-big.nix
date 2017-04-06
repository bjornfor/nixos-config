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
      eclipse = eclipses.eclipse-cpp-46;
      jvmArgs = [ "-Xmx2048m" ];
      plugins = with eclipses.plugins;
        [ cdt gnuarmeclipse ];
    })
    elinks
    evtest
    exiv2
    filezilla
    firefox
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
    jq
    kalibrate-rtl
    lftp
    libfaketime
    libreoffice
    linssid
    lm_sensors
    ltsa
    config.boot.kernelPackages.perf
    ltrace
    lttng-tools
    lynx
    meld
    mercurial
    minicom
    mosh
    msmtp
    mutt
    networkmanager
    networkmanagerapplet
    nfs-utils
    nixops
    nixpkgs-lint
    nix-generate-from-cpan
    nix-prefetch-scripts
    nix-repl
    nox
    nmap_graphical
    offlineimap
    openconnect
    openocd
    openscad
    p7zip
    pencil
    perlPackages.ImageExifTool
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
    shotwell
    sigrok-cli
    silver-searcher
    simplescreenrecorder
    skype
    sloccount
    socat
    solfege
    spice
    spotify
    sqlite-interactive
    srecord
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
