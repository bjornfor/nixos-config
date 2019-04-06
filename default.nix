# Sanity check the repo by evaluating/building all machine configs.

{ pkgs ? import <nixpkgs> {} }:

let
  nixosFunc = import (pkgs.path + "/nixos");

  iso =
    (nixosFunc {
      configuration = {
        imports = [
          (pkgs.path + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
          #(pkgs.path + "/nixos/modules/installer/cd-dvd/installation-cd-graphical-kde.nix")

          # Provide an initial copy of the NixOS channel so that the user
          # doesn't need to run "nix-channel --update" first.
          (pkgs.path + "/nixos/modules/installer/cd-dvd/channel.nix")
        ];

        # Activate SSH at boot
        systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
        users.users.root.openssh.authorizedKeys.keys = with import ./misc/ssh-keys.nix; [
          mini.bf.default
          whitetip.bf.default
        ];
      };
    }).config.system.build.isoImage;

  buildConfig = config:
    (nixosFunc { configuration = config; }) // { recurseForDerivations = true; };
in
{
  inherit iso;
  hydra = buildConfig ./machines/hydra/configuration.nix;
  media = buildConfig ./machines/media/configuration.nix;
  mini = buildConfig ./machines/mini/configuration.nix;
}
