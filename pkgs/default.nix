{ pkgs ? import <nixpkgs> {} }:

{
  altera-quartuses = pkgs.callPackage ./altera-quartus { };

  deconz = pkgs.qt5.callPackage ./deconz {};

  keil-uvision-c51 = pkgs.callPackage ./keil-uvision-c51 { };

  ltsa = pkgs.callPackage ./ltsa/default.nix { };

  roomeqwizard = pkgs.callPackage ./roomeqwizard { };

  # Things for which I'm the author, or wrappers of upstream projects that
  # source custom configs.
  my = pkgs.recurseIntoAttrs {
    custom-desktop-entries = pkgs.callPackage ./custom-desktop-entries {};

    git = pkgs.callPackage ./git { };

    max_perf_pct = pkgs.callPackage ./max_perf_pct { };

    # Added for completeness' sake. (Most likey a .override is in order to
    # customize it appropriately.)
    mini-ci = pkgs.callPackage ./mini-ci { };

    nix-check-before-push = pkgs.callPackage ./nix-check-before-push { };

    tmux = pkgs.callPackage ./tmux { };

    vim = pkgs.callPackage ./vim { };
  };

  winusb = pkgs.callPackage ./winusb/default.nix { };
}
