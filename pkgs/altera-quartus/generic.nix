{ stdenv, fetchurl, utillinux, file, bash, glibc, pkgsi686Linux, writeScript
, nukeReferences, glibcLocales, libfaketime, coreutils, gnugrep, gnused, proot
# Runtime dependencies
, zlib, glib, libpng12, freetype, libSM, libICE, libXrender, fontconfig
, libXext, libX11, libXtst, gtk2, bzip2, libelf
}:

{ baseName
, prettyName ? baseName
, version
, components ? []
, updateComponents ? []

# Set to true for the old installers that are 32-bit only
, is32bitPackage ? false

# There are .so files inside .jar files bundled with Quartus that lack RPATH
# directives. This breaks starting e.g. eclipse-nios2:
#
#   java.lang.UnsatisfiedLinkError: Could not load SWT library. Reasons:
#      $HOME/.altera.sbt4e/16.1.0.196-linux64/configuration/org.eclipse.osgi/bundles/404/1/.cp/libswt-pi-gtk-4335.so: libXtst.so.6: cannot open shared object file: No such file or directory
#      no swt-pi-gtk in java.library.path
#      $HOME/.swt/lib/linux/x86_64/libswt-pi-gtk-4335.so: libXtst.so.6: cannot open shared object file: No such file or directory
#      Can't load library: $HOME/.swt/lib/linux/x86_64/libswt-pi-gtk.so
#
# Although we _could_ fixup these .so files that live inside .jar files (or
# find all java interpreters and specify "-Djava.library.path=" on their
# command line), I don't think it's worth it. Quartus *itself* sets
# LD_LIBRARY_PATH, thus breaking spawning firefox from it, so I see no reason
# we shouldn't be equally lazy.
, wrapWithLdLibraryPath ? true
}:

let
  # Somewhere between NixOS 16.09 and 17.03 (for instance, commit 9e6eec201b)
  # the glibc attribute lacked $out/lib{,64}. The glibc_lib attribute below
  # helped when bisecting build issues between 16.03 and 17.03.
  glibc_lib =
    if glibc ? out then glibc.out else glibc;
  glibc_lib32 =
    if pkgsi686Linux.glibc ? out then pkgsi686Linux.glibc.out else pkgsi686Linux.glibc;

  # Using glibc>=2.25 causes the Quartus*Setup*run installer to hang.
  # Use 2.24 instead.
  commonGlibcAttrs224 = rec {
    name = "glibc-${version}";
    version = "2.24";
    src = fetchurl {
      url = "http://ftpmirror.gnu.org/glibc/${name}.tar.xz";
      sha256 = "1lxmprg9gm73gvafxd503x70z32phwjzcy74i0adfi6ixzla7m4r";
    };
    # Use installLocales and postInstall from nixpkgs-18.09 to prevent build
    # breakage on nixpkgs >= 19.03.
    installLocales = true;
    postInstall = ''
      if test -n "$installLocales"; then
          make -j''${NIX_BUILD_CORES:-1} -l''${NIX_BUILD_CORES:-1} localedata/install-locales
      fi

      test -f $out/etc/ld.so.cache && rm $out/etc/ld.so.cache

      if test -n "$linuxHeaders"; then
          # Include the Linux kernel headers in Glibc, except the `scsi'
          # subdirectory, which Glibc provides itself.
          (cd $dev/include && \
           ln -sv $(ls -d $linuxHeaders/include/* | grep -v scsi\$) .)
      fi

      # Fix for NIXOS-54 (ldd not working on x86_64).  Make a symlink
      # "lib64" to "lib".
      if test -n "$is64bit"; then
          ln -s lib $out/lib64
      fi

      # Get rid of more unnecessary stuff.
      rm -rf $out/var $bin/bin/sln
    ''
      # For some reason these aren't stripped otherwise and retain reference
      # to bootstrap-tools; on cross-arm this stripping would break objects.
    + stdenv.lib.optionalString (stdenv.hostPlatform == stdenv.buildPlatform) ''

      for i in "$out"/lib/*.a; do
          [ "$i" = "$out/lib/libm.a" ] || $STRIP -S "$i"
      done
    '' + ''

      # Put libraries for static linking in a separate output.  Note
      # that libc_nonshared.a and libpthread_nonshared.a are required
      # for dynamically-linked applications.
      mkdir -p $static/lib
      mv $out/lib/*.a $static/lib
      mv $static/lib/lib*_nonshared.a $out/lib
      # Some of *.a files are linker scripts where moving broke the paths.
      sed "/^GROUP/s|$out/lib/lib|$static/lib/lib|g" \
        -i "$static"/lib/*.a

      # Work around a Nix bug: hard links across outputs cause a build failure.
      cp $bin/bin/getconf $bin/bin/getconf_
      mv $bin/bin/getconf_ $bin/bin/getconf
    '';
  };

  # Backport upstream patch to fix build against nixpkgs-18.09.
  glibc_lib_for_installer = glibc_lib.overrideAttrs (oldAttrs:
    commonGlibcAttrs224 // { patches = [ ./patches/glibc/0001-Avoid-.symver-on-common-symbols-BZ-21666.patch ];  }
  );
  glibc_lib32_for_installer = glibc_lib32.overrideAttrs (oldAttrs:
    commonGlibcAttrs224 // { patches = [ ./patches/glibc/0001-Avoid-.symver-on-common-symbols-BZ-21666.patch ];  }
  );

  # Keep in sync with runtimeLibPath64
  # (with pkgsi686Linux; [ .. ] doesn't bind strongly enough.)
  runtimeLibPath32 =
    stdenv.lib.makeLibraryPath
      [ pkgsi686Linux.zlib pkgsi686Linux.glib pkgsi686Linux.libpng12
        pkgsi686Linux.freetype pkgsi686Linux.xorg.libSM pkgsi686Linux.xorg.libICE
        pkgsi686Linux.xorg.libXrender pkgsi686Linux.fontconfig.lib
        pkgsi686Linux.xorg.libXext pkgsi686Linux.xorg.libX11 pkgsi686Linux.xorg.libXtst
        pkgsi686Linux.gtk2 pkgsi686Linux.bzip2.out pkgsi686Linux.libelf
        pkgsi686Linux.stdenv.cc.cc.lib
      ];

  # Keep in sync with runtimeLibPath32
  runtimeLibPath64 =
    stdenv.lib.makeLibraryPath
    [ zlib glib libpng12 freetype libSM libICE libXrender fontconfig.lib
      libXext libX11 libXtst gtk2 bzip2.out libelf
      stdenv.cc.cc.lib
    ];

  runtimeLibPath =
    if is32bitPackage then runtimeLibPath32 else runtimeLibPath64;

  runtimeBinPath = stdenv.lib.makeBinPath
    [ coreutils gnugrep gnused glibc proot ];

  setup-chroot-and-exec = writeScript "setup-chroot-and-exec"
    (''
      #!${bash}/bin/sh
      chrootdir=chroot  # relative to the current directory
      mkdir -p "$chrootdir"/host
      mkdir -p "$chrootdir"/proc
      mkdir -p "$chrootdir"/nix
      mkdir -p "$chrootdir"/tmp
      mkdir -p "$chrootdir"/dev
      mkdir -p "$chrootdir"/lib
      mkdir -p "$chrootdir"/lib64
      mkdir -p "$chrootdir"/bin
      ${utillinux}/bin/mount --rbind /     "$chrootdir"/host
      ${utillinux}/bin/mount --rbind /proc "$chrootdir"/proc
      ${utillinux}/bin/mount --rbind /nix  "$chrootdir"/nix
      ${utillinux}/bin/mount --rbind /tmp  "$chrootdir"/tmp
      ${utillinux}/bin/mount --rbind /dev  "$chrootdir"/dev
    '' + (if is32bitPackage then ''
      ${utillinux}/bin/mount --rbind "${glibc_lib32_for_installer}"/lib "$chrootdir"/lib
    '' else ''
      ${utillinux}/bin/mount --rbind "${glibc_lib_for_installer}"/lib64 "$chrootdir"/lib64
    '') + ''
      ${utillinux}/bin/mount --rbind "${bash}"/bin "$chrootdir"/bin
      chroot "$chrootdir" "$@"
    '');

  # buildFHSUserEnv from nixpkgs tries to mount a few directories that are not
  # available in sandboxed Nix builds (/sys, /run), hence we have our own
  # slimmed down variant.
  run-in-fhs-env = writeScript "run-in-fhs-env"
    ''
      #!${bash}/bin/sh
      if [ "$*" = "" ]; then
          echo "Usage: run-in-fhs-env <COMMAND> [ARGS...]"
          exit 1
      fi
      "${utillinux}/bin/unshare" -r -U -m "${setup-chroot-and-exec}" "$@"
    '';

  mkInstallersDir = srcs:
    stdenv.mkDerivation rec {
      name = "${baseName}-installers";
      inherit srcs version;
      buildCommand =
        ''
          # The files are copied, not symlinked, because
          #   - We must add execute bit to *.run files
          #   - Quartus*Setup*.run fails to use the *.qdz files if they are symlinks.
          #     Example error message (which doesn't abort the installer!):
          #     Error copying file from /nix/store/HASH1-altera-quartus-prime-lite-installers-16.1.0.196/cyclonev-16.1.0.196.qdz/cyclonev-16.1.0.196.qdz to /nix/store/HASH2-altera-quartus-prime-lite-16.1.0.196/cyclonev-16.1.0.196.qdz:
          #     /nix/store/HASH1-altera-quartus-prime-lite-installers-16.1.0.196/cyclonev-16.1.0.196.qdz/cyclonev-16.1.0.196.qdz does not exist
          #     Abort
          #     Unable to copy file

          mkdir -p "$out"
          ${stdenv.lib.concatStringsSep "\n"
            (map
              (p: ''
                cp "${p}" "$out/$(stripHash "${p}")"
              '')
              srcs
            )
          }
          chmod +x "$out"/*.run
        '';
    };

  componentInstallers = mkInstallersDir components;

  updateComponentInstallers = mkInstallersDir updateComponents;

  quartusUnwrapped = stdenv.mkDerivation rec {
    name = "${baseName}-unwrapped-${version}";
    inherit version;
    # srcs is for keeping track of inputs used for the build.
    srcs = components ++ updateComponents;
    buildInputs = [ file nukeReferences ];

    # Fix this:
    # /nix/store/...-altera-quartus-ii-web-13.1.4.182/quartus/adm/qenv.sh: line 83: \
    #  warning: setlocale: LC_CTYPE: cannot change locale (en_US.UTF-8): No such file or directory
    LOCALE_ARCHIVE = "${glibcLocales}/lib/locale/locale-archive";

    # Prebuilt binaries need special treatment
    dontStrip = true;
    dontPatchELF = true;
    # Fix "RPATH of binary X contains a forbidden reference to /build" issue.
    # (These are prebuilt binaries, not much we can do.)
    noAuditTmpdir = true;

    configurePhase = "true";
    buildPhase = "true";
    unpackPhase = "true";

    # Quartus' setup.sh (from the all-in-one-installers) doesn't fit our needs
    # (we want automatic and distro-agnostic install), so call the actual setup
    # program directly instead.
    #
    # Quartus*Setup*.run files are statically linked ELF executables that run
    # open("/lib64/ld-linux-x86-64.so.2", ...) (or "/lib/ld-linux.so.2" for
    # 32-bit versions) . That obviously doesn't work in sandboxed Nix builds.
    #
    # Things that do not work:
    # * patchelf the installer (there is no .interp section in static ELF)
    # * dynamic linker tricks (again, static ELF)
    # * proot (the installer somehow detects something is wrong and aborts)
    #
    # We need bigger guns: user namespaces and chroot. That's how we make /lib64/
    # available to the installer. The installer installs dynamically linked ELF
    # files, so those we can fixup with usual tools.
    #
    # For runtime, injecting (or wrapping with) LD_LIBRARY_PATH is easier, but it
    # messes with the environment for all child processes. We take the less
    # invasive approach here, patchelf + RPATH. Unfortunately, Quartus itself
    # uses LD_LIBRARY_PATH in its wrapper scripts. This cause e.g. firefox to
    # fail due to LD_LIBRARY_PATH pulling in wrong libraries for it (happens if
    # clicking any URL in Quartus).
    installPhase = ''
      run_quartus_installer()
      {
          installer="$1"
          if [ ! -x "$installer" ]; then
              echo "ERROR: \"$installer\" either doesn't exist or is not executable"
              exit 1
          fi
          maybe_accept_eula="${if stdenv.lib.versionAtLeast version "17.1" then "--accept_eula 1" else ""}"
          echo "### ${run-in-fhs-env} $installer --mode unattended --installdir $out" $maybe_accept_eula
          "${run-in-fhs-env}" "$installer" --mode unattended --installdir "$out" $maybe_accept_eula
          echo "...done"
      }

      echo "Running Quartus Setup (in FHS sandbox)..."
      run_quartus_installer "$(echo "${componentInstallers}"/Quartus*Setup*)"

      ${stdenv.lib.optionalString (updateComponents != []) ''
        echo "Running Quartus Update (in FHS sandbox)..."
        run_quartus_installer "$(echo "${updateComponentInstallers}"/Quartus*Setup*)"
      ''}

      echo "Removing unneeded \"uninstall\" binaries (saves $(du -sh "$out"/uninstall | cut -f1))"
      rm -rf "$out"/uninstall

      echo "Prevent retaining a runtime dependency on the installer binaries (saves $(du -sh "${componentInstallers}" | cut -f1) + $(du -sh "${updateComponentInstallers}" | cut -f1))"
      nuke-refs "$out/logs/"*

      echo "Fixing ELF interpreter paths with patchelf"
      find "$out" -type f | while read f; do
          case "$f" in
              *.debug) continue;;
          esac
          # A few files are read-only. Make them writeable for patchelf. (Nix
          # will make all files read-only after the build.)
          chmod +w "$f"
          magic=$(file "$f") || { echo "file \"$f\" failed"; exit 1; }
          case "$magic" in
              *ELF*dynamically\ linked*)
                  orig_rpath=$(patchelf --print-rpath "$f") || { echo "FAILED: patchelf --print-rpath $f"; exit 1; }
                  # Take care not to add ':' at start or end of RPATH, because
                  # that is the same as '.' (current directory), and that's
                  # insecure.
                  if [ "$orig_rpath" != "" ]; then
                      orig_rpath="$orig_rpath:"
                  fi
                  new_rpath="$orig_rpath${runtimeLibPath}"
                  case "$magic" in
                      *ELF*pie\ executable*|*ELF*shared\ object*x86-64*)
                          patchelf --set-rpath "$new_rpath" "$f" || { echo "FAILED: patchelf --set-rpath $f"; exit 1; }
                          ;;
                      *ELF*executable*)
                          interp=$(patchelf --print-interpreter "$f") || { echo "FAILED: patchelf --print-interpreter $f"; exit 1; }
                          # Note the LSB interpreters, required by some files
                          case "$interp" in
                              /lib64/ld-linux-x86-64.so.2|/lib64/ld-lsb-x86-64.so.3)
                                  new_interp=$(cat "$NIX_CC"/nix-support/dynamic-linker)
                                  ;;
                              /lib/ld-linux.so.2|/lib/ld-lsb.so.3)
                                  new_interp="${glibc_lib32}/lib/ld-linux.so.2"
                                  ;;
                              /lib/ld-linux-armhf.so.3|/lib64/ld64.so.1|/lib64/ld64.so.2)
                                  # Ignore ARM/ppc64/ppc64le executables, they
                                  # are not meant to be run on the build machine.
                                  # Example files:
                                  #   altera-quartus-prime-lite-15.1.0.185/hld/host/arm32/bin/aocl-binedit
                                  #   altera-quartus-prime-lite-15.1.0.185/hld/host/ppc64/bin/aocl-binedit
                                  #   altera-quartus-prime-lite-15.1.0.185/hld/host/ppc64le/bin/aocl-binedit
                                  continue
                                  ;;
                              *)
                                  echo "FIXME: unhandled interpreter \"$interp\" in $f"
                                  exit 1
                                  ;;
                          esac
                          test -f "$new_interp" || { echo "$new_interp is missing"; exit 1; }
                          patchelf --set-interpreter "$new_interp" \
                                   --set-rpath "$new_rpath" "$f" || { echo "FAILED: patchelf --set-interpreter $new_interp --set-rpath $new_rpath $f"; exit 1; }
                          ;;
                  esac
                  ;;
              *ELF*statically\ linked*)
                  echo "WARN: $f is statically linked. Needs fixup?"
                  ;;
          esac
      done

      # Modelsim is optional
      f="$out"/modelsim_ase/vco
      if [ -f "$f" ]; then
          echo "Fix hardcoded \"/bin/ls\" in .../modelsim_ase/vco"
          sed -i -e "s,/bin/ls,ls," "$f"

          echo "Fix support for Linux 4.x in .../modelsim_ase/vco"
          sed -i -e "/case \$utype in/a 4.[0-9]*) vco=\"linux\" ;;" "$f"
      fi
    '';
  };

in

stdenv.mkDerivation rec {
  name = "${baseName}-${version}";
  # version and srcs are unused by this derivation, but keep them as metadata
  # (for users).
  inherit (quartusUnwrapped) version srcs;
  buildCommand = ''
    # Provide convenience wrappers in $out/bin, so that the tools can be
    # started directly from PATH. Plain symlinks don't work, due to assumptions
    # of resources relative to arg0.
    wrap()
    {
        dest="$out/bin/$(basename "$1")"
        if [ -f "$dest" ]; then
            echo "ERROR: $dest already exist"
            exit 1
        fi
        cat > "$dest" << EOF
    #!${bash}/bin/sh

    # Some tools seem to forget sourcing their environment setup file (e.g
    # elf2hex), so help them by setting QUARTUS_ROOTDIR (and *OVERRIDE).
    # (Perhaps these tools were never tested _not_ being started from Quartus
    # IDE?)
    export QUARTUS_ROOTDIR="${quartusUnwrapped}/quartus"
    export QUARTUS_ROOTDIR_OVERRIDE="\$QUARTUS_ROOTDIR"

    # To prevent e.g. "alt-file-convert" from aborting due to not being able to
    # write to __pycache__ in the (read-only) nix store.
    export PYTHONDONTWRITEBYTECODE=1

    ${stdenv.lib.optionalString wrapWithLdLibraryPath ''
      if [ "x\$LD_LIBRARY_PATH" != x ]; then
          export LD_LIBRARY_PATH="${runtimeLibPath}:\$LD_LIBRARY_PATH"
      else
          export LD_LIBRARY_PATH="${runtimeLibPath}"
      fi
    ''}

    # Inject path to known tools. This is important not only for having a
    # complete package (all deps), but also to ensure that LD_PRELOAD etc.
    # won't break the CLI tools. (Think non-NixOS setups.)
    export PATH="${runtimeBinPath}:\$PATH"

    # Check if we need to isolate ourself from /bin/sh. This is to work around
    # a long standing bug in nixpkgs that glibc system() calls /bin/sh. The
    # reasoning behind the test is that Nix tools don't depend on things in
    # /lib. The test should be positive only on non-sandboxed, non-NixOS builds.
    bin_sh_is_clean=1
    if ldd /bin/sh | grep -q "^\s*/lib"; then
        bin_sh_is_clean=0
    fi

    # Implement the SOURCE_DATE_EPOCH specification, for reproducible builds:
    # https://reproducible-builds.org/specs/source-date-epoch
    if [ "x\$SOURCE_DATE_EPOCH" != x ]; then
        # Create a minimal "sandbox" with proot, or else programs running
        # /bin/sh will fail because we're setting LD_PRELOAD etc.
        if [ \$bin_sh_is_clean -eq 0 ]; then
            maybe_proot_cmd="proot -b ${bash}/bin/sh:/bin/sh"
            # Work around bug with linux 4.8.4+ (costs some performance, but
            # prevents breakage).
            export PROOT_NO_SECCOMP=1
        fi
        # Prepare LD_LIBRARY_PATH, LD_PRELOAD
        if [ "x\$LD_LIBRARY_PATH" != x ]; then
            export LD_LIBRARY_PATH="${libfaketime}/lib:\$LD_LIBRARY_PATH"
        else
            export LD_LIBRARY_PATH="${libfaketime}/lib"
        fi
        if [ "x${toString is32bitPackage}" = "x${toString true}" ]; then
            export LD_LIBRARY_PATH="${pkgsi686Linux.libfaketime}/lib:\$LD_LIBRARY_PATH"
        fi
        if [ "x\$LD_PRELOAD" != x ]; then
            export LD_PRELOAD="libfaketime.so.1:\$LD_PRELOAD"
        else
            export LD_PRELOAD=libfaketime.so.1
        fi
        # Set the time to SOURCE_DATE_EPOCH
        export FAKETIME_FMT="%s"
        export FAKETIME=\$(date +%s -d @\$SOURCE_DATE_EPOCH)
    fi

    # Fix this:
    # /nix/store/...-altera-quartus-ii-web-13.1.4.182/quartus/adm/qenv.sh: line 83: \
    #  warning: setlocale: LC_CTYPE: cannot change locale (en_US.UTF-8): No such file or directory
    export LOCALE_ARCHIVE="${glibcLocales}/lib/locale/locale-archive"

    exec \$maybe_proot_cmd "$1" "\$@"
    EOF
        chmod +x "$dest"
    }

    echo "Creating top-level bin/ directory with wrappers for common tools"
    mkdir -p "$out/bin"
    for p in "${quartusUnwrapped}/"*"/bin/"*; do
        test -f "$p" || continue
        wrap "$p"
    done

    echo "Installing Desktop file..."
    mkdir -p "$out/share/applications"
    f="$out"/share/applications/quartus.desktop
    cat >> "$f" << EOF
    [Desktop Entry]
    Type=Application
    Name=${prettyName} ${version}
    Comment=${prettyName} ${version}
    Icon=${quartusUnwrapped}/quartus/adm/quartusii.png
    Exec=$out/bin/quartus
    Terminal=false
    Path=$out
    EOF

    # udev rules based on
    # https://www.intel.com/content/www/us/en/programmable/support/support-resources/download/drivers/dri-usb_b-lnx.html
    echo "Installing udev rules"
    mkdir -p "$out/lib/udev/rules.d"
    cat > "$out/lib/udev/rules.d/51-usbblaster.rules" << EOF
    # USB-Blaster / Intel FPGA Download Cable
    SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6001", MODE="0666"
    SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6002", MODE="0666"
    SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6003", MODE="0666"

    # USB-Blaster II / Intel FPGA Download Cable II
    SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6010", MODE="0666"
    SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6810", MODE="0666"
    EOF
  '';

  meta = with stdenv.lib; {
    description = "Development tools for Altera FPGA, CPLD and SoC designs";
    homepage = https://www.altera.com/;
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ maintainers.bjornfor ];
  };
}
