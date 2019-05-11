{ stdenv, fetchurl, openjdk8, coreutils, gawk, gnused, gnugrep }:

stdenv.mkDerivation rec {
  name = "roomeqwizard-${version}";
  version = "5.19";

  src = fetchurl {
    url = "https://www.roomeqwizard.com/installers/REW_linux_5_19.sh";
    sha256 = "0xvxb8x16yh97n0p6nj9dnzvficgqkywdi3gds0skkqccgv2dwlb";
  };

  buildInputs = [ openjdk8 ];

  unpackPhase = "true";

  # Pre-built software
  buildPhase = "true";

  installPhase = ''
    # First, keep a ref to the source, in case it disappears from the Internet.
    mkdir -p "$out/share/REW"
    ln -s "${src}" "$out/share/REW/installer-${version}.sh"

    # Run the installer, with prepared answers.
    (echo o           # "This will install Room EQ Wizard on your computer." OK?
     echo             # view next page of license text
     echo             # view next page of license text
     echo 1           # accept the license agreement
     echo "$out/REW"  # where to install
     echo y           # create symlinks?
     echo "$out/bin/" # where to create symlinks
     echo y           # create desktop icon?
    ) | sh "$src"

    # Remove unneded scripts
    rm "$out/REW/uninstall"

    # Fix location of the desktop file.
    mkdir -p "$out/share/applications"
    mv "$out/REW/REW.desktop" "$out/share/applications"
    # Specify an icon, since upstream doesn't provide one.
    echo "Icon=$out/REW/.install4j/s_yn6vx9.png" >> "$out/share/applications/REW.desktop"

    # * Give the startup script a java package to use.
    # * Don't rely on finding progs in PATH. Mind the trailing space when
    #   matching "ls " (since not all "ls" should be modified).
    sed -e "s|^INSTALL4J_JAVA_HOME_OVERRIDE=.*|INSTALL4J_JAVA_HOME_OVERRIDE=${openjdk8}|" \
        -e "s|\<basename\>|${coreutils}/bin/basename|" \
        -e "s|\<dirname\>|${coreutils}/bin/dirname|" \
        -e "s|\<ls\> |${coreutils}/bin/ls |" \
        -e "s|\<expr\>|${coreutils}/bin/expr|" \
        -e "s|\<rm\>|${coreutils}/bin/rm|" \
        -e "s|\<mv\>|${coreutils}/bin/mv|" \
        -e "s|\<chmod\>|${coreutils}/bin/chmod|" \
        -e "s|\<awk\>|${gawk}/bin/awk|" \
        -e "s|\<sed\>|${gnused}/bin/sed|" \
        -e "s|\<egrep\>|${gnugrep}/bin/egrep|" \
        -i "$out/REW/roomeqwizard"

    # Add udev rules for the MiniDSP UMIK-1 calibrated USB microphone that is
    # recommended for use with REW.
    mkdir -p "$out/lib/udev/rules.d"
    cat > "$out/lib/udev/rules.d/90-roomeqwizard.rules" << EOF
    # MiniDSP UMIK-1 calibrated USB microphone
    SUBSYSTEM=="usb", ATTR{idVendor}=="2752", ATTR{idProduct}=="0007", TAG+="uaccess"
    EOF
  '';

  meta = with stdenv.lib; {
    description = "Measuring and analysing room and loudspeaker responses";
    homepage = "https://www.roomeqwizard.com/";
    license = licenses.unfree;
    # this expression is limited to linux, but upstream supports more
    platforms = platforms.linux;
    maintainers = [ maintainers.bjornfor ];
  };
}
