{ pkgs, lib, ... }:

{
  imports = [
    ./dconf.nix
    ./shell.nix
  ];
}
