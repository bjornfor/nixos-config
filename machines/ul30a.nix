{ config, lib, pkgs, ... }:

{
  imports = [
    ../config/base-big.nix
    # Skype sees the Asus UL30A camera as upside down. Flip it back.
    ../config/skype-flip-camera.nix
  ];

  fileSystems = {
    "/".device = "/dev/disk/by-label/nixos-ssd";
  };

  boot.loader.grub.device =
    "/dev/disk/by-id/ata-INTEL_SSDSA2CW160G3_CVPR106000FW160DGN";

  networking.hostName = "ul30a";

  services = {
    munin-node.extraConfig = ''
      cidr_allow 192.168.1.0/24
    '';
    munin-cron = {
      hosts = ''
        [mini]
        address mini.local
      '';
    };
  };
}
