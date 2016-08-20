{ pkgs, ... }:

with pkgs;

{
  ltsa = callPackage ./ltsa/default.nix { };

  spotify-ripper = callPackage ./spotify-ripper/default.nix { };
}
