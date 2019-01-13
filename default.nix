# Sanity check the repo by evaluating/building all machine configs.

{ pkgs ? import <nixpkgs> {} }:

let
  nixosFunc = import (pkgs.path + "/nixos");
  buildConfig = config:
    (nixosFunc { configuration = config; }) // { recurseForDerivations = true; };
in
{
  hydra = buildConfig ./machines/hydra/configuration.nix;
  media = buildConfig ./machines/media/configuration.nix;
  mini = buildConfig ./machines/mini/configuration.nix;
}
