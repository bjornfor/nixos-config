{ config, lib, pkgs, ... }:

let
  hostAddrs = config.local.resources.hostAddrs;
in
{
  networking.extraHosts =
    let
      list = lib.mapAttrsToList (n: v: "${v} ${n}") hostAddrs;
      extraHosts = lib.concatStringsSep "\n" list;
    in
      extraHosts;
}
