{ pkgs ? import <nixpkgs> {} }:

{
  altera-quartuses = pkgs.callPackage ./altera-quartus { };

  keil-uvision-c51 = pkgs.callPackage ./keil-uvision-c51 { };

  libfaketime = pkgs.libfaketime.overrideAttrs (oldAttrs: rec {
    name = "libfaketime-${version}";
    version = "0.9.7";
    src = pkgs.fetchurl {
      url = "https://github.com/wolfcw/libfaketime/archive/v${version}.tar.gz";
      sha256 = "07l189881q0hybzmlpjyp7r5fwz23iafkm957bwy4gnmn9lg6rad";
    };
  });

  ltsa = pkgs.callPackage ./ltsa/default.nix { };

  # Things for which I'm the author
  my = pkgs.recurseIntoAttrs {
    max_perf_pct = pkgs.callPackage ./max_perf_pct { };

    # Added for completeness' sake. (Most likey a .override is in order to
    # customize it appropriately.)
    mini-ci = pkgs.callPackage ./mini-ci { };

    nix-check-before-push = pkgs.callPackage ./nix-check-before-push { };
  };

  winusb = pkgs.callPackage ./winusb/default.nix { };
}
