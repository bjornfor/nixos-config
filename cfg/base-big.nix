{ config, lib, pkgs, ... }:

{
  imports = [
    ./base-medium.nix
  ];

  environment.systemPackages = with pkgs; [
    (asciidoc-full.override { enableExtraPlugins = true; })
    anki  # flash card learning application
    aspell
    aspellDicts.en
    aspellDicts.nb
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
      eclipse = eclipses.eclipse-cpp;
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
    graphviz
    gsmartcontrol
    hexchat
    iftop
    ioping
    irssi
    lftp
    libfaketime
    libreoffice
    linssid
    ltsa
    config.boot.kernelPackages.perf
    ltrace
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
    roomeqwizard
    saleae-logic
    shotwell
    sigrok-cli
    simplescreenrecorder
    skype
    slack
    sloccount
    socat
    solfege
    spice
    spotify
    srecord
    stellarium
    strace
    subversion
    surfraw
    sweethome3d.application
    #teamviewer  # changes hash all the time
    unoconv
    virtmanager
    virtviewer
    wineUnstable
    winpdb
    wirelesstools
    wpa_supplicant
    wpa_supplicant_gui
    youtube-dl
    zoom-us
  ];
}
