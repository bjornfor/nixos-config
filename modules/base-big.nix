{ config, lib, pkgs, ... }:

let
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
    ./base.nix
  ];

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
    dmidecode
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
    config.boot.kernelPackages.perf
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
}
