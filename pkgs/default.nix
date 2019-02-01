{ pkgs ? import <nixpkgs> {} }:

{
  altera-quartuses = pkgs.callPackage ../pkgs/altera-quartus { };

  keil-uvision-c51 = pkgs.callPackage ../pkgs/keil-uvision-c51 { };

  libfaketime = pkgs.libfaketime.overrideAttrs (oldAttrs: rec {
    name = "libfaketime-${version}";
    version = "0.9.7";
    src = pkgs.fetchurl {
      url = "https://github.com/wolfcw/libfaketime/archive/v${version}.tar.gz";
      sha256 = "07l189881q0hybzmlpjyp7r5fwz23iafkm957bwy4gnmn9lg6rad";
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
}
