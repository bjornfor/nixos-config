# Sanity check the repo by evaluating/building all machine configs.

{ branch ? "pinned"  # default to pinned/reproducible
, nixpkgs ? import ./inputs/nixpkgs.nix { inherit branch; }
, pkgs ? let p = import nixpkgs { config = import ./cfg/nixpkgs-config.nix; overlays = []; }; in builtins.trace "nixpkgs version: ${p.lib.version} (rev: ${nixpkgs.rev or "unknown"})" p
}:

let
  nixosFunc = import (pkgs.path + "/nixos");

  iso = import ./isos/livecd/default.nix { inherit pkgs; };

  buildConfig = config:
    # FIXME: Machines that set 'boot.loader.systemd-boot.enable = true' fail to
    # build the vmWithBootloader attribute, ref
    # https://github.com/NixOS/nixpkgs/pull/65133.
    pkgs.lib.filterAttrs
    (n: v: if n == "vmWithBootLoader"
           then pkgs.lib.warn "FIXME: skipping vmWithBootLoader" false
           else true
    )
    ((nixosFunc { configuration = config; }) // { recurseForDerivations = true; });
in
{
  inherit iso;
  localPkgs = import ./pkgs/default.nix { inherit pkgs; };
  machines = pkgs.recurseIntoAttrs {
    media = buildConfig ./machines/media/configuration.nix;
    mini = buildConfig ./machines/mini/configuration.nix;
    srv1 = buildConfig ./machines/srv1/configuration.nix;
  };
}
