{ config, lib, pkgs, ... }:

{
  nixpkgs.config = {
    packageOverrides = pkgs: {
      inherit (pkgs.callPackages ../packages/default.nix { })
        ltsa spotify-ripper;
    };
  };
}
