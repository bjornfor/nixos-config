{ stdenv, fetchurl, wine, coreutils }:

stdenv.mkDerivation rec {
  name = "keil-uvision-c51-${version}";
  version = "9.56"; # "Help -> About uVision" shows "5.20.0.39"

  # Packaging issues:
  # * Installer only available for Windows
  # * Installer does not support unattended installs.
  #   As a workaround we run the installer manually and create a package of the
  #   resulting files:
  #
  #     mkdir /tmp/wine-keil
  #     export WINEPREFIX=/tmp/wine-keil
  #     wine c51v956.exe  # run the installer
  #     # Optional steps, for full version:
  #     #  - If you have an, ehm, "alternate" L51.dll file, copy it over the
  #     #    original now ($WINEPREFIX/drive_c/Keil_v5/C51/BIN/L51.dll).
  #     #  - Start UV4.exe once to populate the registry:
  #     #    $ wine $WINEPREFIX/drive_c/Keil_v5/UV4/UV4.exe
  #     #  - Make backup of registry:
  #     #    $ cp $WINEPREFIX/system.reg{,.1}
  #     #  - Add license (start UV4.exe and go to "File -> License Management",
  #     #    add the license, click "close" for the registry to be written to disk)
  #     #  - Make another backup of the registry:
  #     #    $ cp $WINEPREFIX/system.reg{,.2}
  #     #  - Diff the two registry files to find out which keys should be
  #     #    exported to have working license. If you only added _one_ license,
  #     #    there will be _two_ keys that need to be exported.
  #     #    The registry keys look something like this:
  #     #    "HKEY_LOCAL_MACHINE\\Software\\Classes\\K10.0GACE.K\\CXSID"
  #     #    "HKEY_LOCAL_MACHINE\\Software\\Classes\\{4E50B08E-28CB-44DA-B5B4-EFC45C1EBE6B}"
  #     #    If you added several licenses, you have to export all keys related
  #     #    to the license, or create a .reg file manually based on the
  #     #    diff (export one or two keys with "regedit" first to see what the
  #     #    format looks like -- the input format is slightly different from
  #     #    the format stored in ~/.wine/system.reg!).
  #     #  - Export the keys:
  #     #    $ wine regedit /E $WINEPREFIX/drive_c/Keil_v5/license-info-1.reg "HKEY_LOCAL_MACHINE\\Software\\Classes\\<SOME_MAGIC_HERE>\\CXSID"
  #     #    $ wine regedit /E $WINEPREFIX/drive_c/Keil_v5/license-info-2.reg "HKEY_LOCAL_MACHINE\\Software\\Classes\\{<SOME_UUID_LIKE_HERE>}"
  #     #    The UV4 wrapper script will load all registry files matching
  #     #    "license-info*.reg" pattern in the Keil_v5/ directory.
  #     (cd $WINEPREFIX/drive_c/ && tar cvJf /tmp/keil-uvision-c51-9.56-preinstalled.tar.xz ./Keil_v5)
  #
  # [NOTES]
  # ----
  # If you want to add a license, you have to do that _before_ creating
  # the tarball. Adding a license when the installation files are in the Nix
  # store (read-only) will not work. (The license ID is stored in
  # $WINEPREFIX/drive_c/Keil_v5/TOOLS.INI).
  #
  # Instead of exporting the (exact) license keys from the registry, one could
  # simply copy the whole system.reg file. However, that would force running
  # this program in a separate $WINEPREFIX to not mess with the existing
  # registry.
  #
  # Since we don't preserve the whole registry, we lose some information that
  # the installer sets up. For instance, file associations, and wine/windows
  # not knowing that this program is "installed". It's a tradeoff.
  # ----

  src = fetchurl {
    url = file:///tmp/keil-uvision-c51-9.56-preinstalled.tar.xz;
    sha256 = "135d2baa054046fff7fe706ac67509bb701ff8f04e1cb7b1e82fb1e588b0f6dd";
  };

  buildCommand = ''
    mkdir -p "$out/bin"
    mkdir -p "$out/wine/drive_c/"

    cp ${./UV4} "$out/bin/UV4"
    chmod +x "$out/bin/UV4"
    tar xvf "$src" -C "$out/wine/drive_c/"

    substituteInPlace "$out/bin/UV4" \
        --replace @wine@ ${wine} \
        --replace @coreutils@ ${coreutils} \
        --replace @out@ "$out"
  '';

  meta = with stdenv.lib; {
    description = "IDE for embedded development";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ]; # only tested this
    maintainers = [ maintainers.bjornfor ];
  };
}
