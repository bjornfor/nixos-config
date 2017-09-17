# Nixpkgs configuration file.

{
  allowUnfree = true;  # allow proprietary packages

  firefox.enableAdobeFlash = true;
  chromium.enablePepperFlash = true;

  packageOverrides = pkgs: {
    altera-quartuses = pkgs.callPackage ../packages/altera-quartus { };

    keil-uvision-c51 = pkgs.callPackage ../packages/keil-uvision-c51 { };

    ltsa = pkgs.callPackage ../packages/ltsa/default.nix { };

    mtdutils-for-swupdate = pkgs.mtdutils.overrideDerivation (args: rec {
      # Copied from the .bbappend file from meta-swupdate.
      postInstall = ''
        mkdir -p "$out/lib"
        mkdir -p "$out/include/mtd"
        cp lib/libmtd.a "$out/lib"
        cp ubi-utils/libubi*.a "$out/lib"
        install -m 0644 ubi-utils/include/libubi.h $out/include/mtd/
        install -m 0644 include/libmtd.h $out/include/mtd/
        install -m 0644 include/mtd/ubi-media.h $out/include/mtd/
      '';
    });

    spotify-ripper = pkgs.callPackage ../packages/spotify-ripper/default.nix { };

    winusb = pkgs.callPackage ../packages/winusb/default.nix { };
  };
}
