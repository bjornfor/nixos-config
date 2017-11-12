# Nixpkgs configuration file.

{
  allowUnfree = true;  # allow proprietary packages

  firefox.enableAdobeFlash = true;
  chromium.enablePepperFlash = true;

  packageOverrides = pkgs: {
    altera-quartuses = pkgs.callPackage ../pkgs/altera-quartus { };

    keil-uvision-c51 = pkgs.callPackage ../pkgs/keil-uvision-c51 { };

    # Upcoming release fixes segfault when run with Altera Quartus
    libfaketime = pkgs.libfaketime.overrideAttrs (oldAttrs: rec {
      name = "libfaketime-${version}";
      version = "0.9.7b1";
      src = pkgs.fetchurl {
        url = "https://github.com/wolfcw/libfaketime/archive/v${version}.tar.gz";
        sha256 = "08id74z44a2szk1rmwsc46hjksvahjkyyxxy484yq0z1p4gm2w9n";
      };
    });

    ltsa = pkgs.callPackage ../pkgs/ltsa/default.nix { };

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

    spotify-ripper = pkgs.callPackage ../pkgs/spotify-ripper/default.nix { };

    winusb = pkgs.callPackage ../pkgs/winusb/default.nix { };
  };
}
