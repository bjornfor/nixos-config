# A NixOS live CD with ssh enabled.

{ pkgs }:

let
  nixosFunc = import (pkgs.path + "/nixos");

  iso = (nixosFunc {
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
      users.users.root.openssh.authorizedKeys.keys = with import ../../resources/ssh-keys.nix; [
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
in
  iso
