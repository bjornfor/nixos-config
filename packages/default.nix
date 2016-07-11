{ pkgs, ... }:

with pkgs;

{
  ltsa = callPackage ./ltsa/default.nix { };
}
