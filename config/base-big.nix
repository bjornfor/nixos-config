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
    aspell
    aspellDicts.en
    aspellDicts.nb
    attic
    babeltrace
    bind
    bmon
    llvmPackages.clang   # for libclang, required by clang_complete.vim
    clangAnalyzer  # a.k.a. scan-build
    cmakeWithGui
    dash
    dhex
    dia
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
    filezilla
    freecad
    gitAndTools.qgit
    gnome3.dconf  # Required by virt-manager to store settings (dconf-service will be started when needed). NOTE: enabling GNOME 3 desktop auto-enables this.
    gource
    gparted
    gqrx
    graphviz
    gsmartcontrol
    hexchat
    iftop
    ioping
    irssi
    kalibrate-rtl
    lftp
    libfaketime
    libreoffice
    linssid
    ltsa
    config.boot.kernelPackages.perf
    ltrace
    lttng-tools
    lynx
    meld
    mercurial
    nfs-utils
    nmap_graphical
    offlineimap
    openconnect
    openocd
    openscad
    pencil
    (pidgin-with-plugins.override { plugins = [ pidginsipe ]; })
    poppler
    pulseview  # sigrok GUI
    pwgen
    qemu
    qmmp
    #qtcreator
    remake
    remmina
    rtl-sdr
    saleae-logic
    shotwell
    sigrok-cli
    simplescreenrecorder
    skype
    sloccount
    socat
    solfege
    spice
    spotify
    srecord
    stellarium
    subversion
    surfraw
    sweethome3d.application
    #teamviewer  # changes hash all the time
    telnet
    unoconv
    virtmanager
    virtviewer
    weston
    wineUnstable
    winpdb
    wirelesstools
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
