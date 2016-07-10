{ config, lib, pkgs, ... }:

{
  imports = [
    ./modules/base.nix
  ];

  fileSystems = {
    "/".device = "/dev/disk/by-label/nixos-ssd";
  };

  boot.loader.grub.device =
    "/dev/disk/by-id/ata-INTEL_SSDSA2CW160G3_CVPR106000FW160DGN";

  networking.hostName = "ul30a";

  nixpkgs.config = {
    packageOverrides = pkgs: {
      skype = # Skype sees the Asus UL30A camera as upside down. Flip it back.
        let
          libv4l_i686 = pkgs.callPackage_i686 <nixpkgs/pkgs/os-specific/linux/v4l-utils> { qt5 = null; };
        in
        lib.overrideDerivation pkgs.skype (attrs: {
          installPhase = attrs.installPhase +
            ''
              sed -i "2iexport LD_PRELOAD=${libv4l_i686}/lib/v4l1compat.so" "$out/bin/skype"
            '';
        });
    };
  };

  services = {
    munin-cron = {
      hosts = ''
        [mini]
        address mini.local
      '';
    };
  };
}
