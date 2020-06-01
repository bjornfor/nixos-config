# Sanity check the repo by evaluating/building all machine configs.

{ branch ? "pinned"  # default to pinned/reproducible
, nixpkgs ? import ./inputs/nixpkgs.nix branch
, pkgs ? let p = import nixpkgs { config = {}; overlays = []; }; in builtins.trace "nixpkgs version: ${p.lib.version} (rev: ${nixpkgs.rev or "unknown"})" p
}:

let
  nixosFunc = import (pkgs.path + "/nixos");

  iso =
    (nixosFunc {
      configuration = {
        imports = [
          (pkgs.path + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
          #(pkgs.path + "/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix")
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

        isoImage.contents = [
          { source = pkgs.writeText "readme"
              ''
                Custom NixOS installer built from @bjornfor's nixos-config git repo.
              '';
            target = "/README.txt";
          }
        ];
      };
    }).config.system.build.isoImage;

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
