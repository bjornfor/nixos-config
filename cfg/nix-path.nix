{ config, lib, pkgs, ... }:

let
  dummyNixChannel = pkgs.writeShellScriptBin "nix-channel" ''
     echo "nix-channel has been disabled on this machine." >&2
     exit 1
  '';
in
{
  nix.nixPath = [
    # This is a symlink that is created below. Using a symlink instead of
    # direct store path allows using the new nixpkgs without having to
    # re-login.
    "nixpkgs=/etc/current-nixpkgs"

    # After initial bootstrap with `nixos-rebuild boot -I
    # nixos-config=/etc/nixos/$MACHINE/configuration.nix`, the machine
    # remembers its configuration file.
    "nixos-config=/etc/nixos/machines/${config.networking.hostName}/configuration.nix"
  ];

  # Inspired by https://github.com/NixOS/nix/pull/1731#issuecomment-558126263,
  # but using the option environment.etc instead of nixos internal
  # system.extraSystemBuilderCmds.
  environment.etc.current-nixpkgs.source = let
    # make sure store paths are not copied to the store again, which leads to
    # long filenames (https://github.com/NixOS/nix/issues/1728)
    nixpkgs_str = if lib.isStorePath pkgs.path then builtins.storePath pkgs.path else pkgs.path;
  in
    nixpkgs_str;

  environment.systemPackages = [
    (lib.hiPrio dummyNixChannel)
  ];
}
