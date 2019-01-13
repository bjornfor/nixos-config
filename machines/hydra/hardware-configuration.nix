# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, ... }:

{
  imports =
    [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    ];

  # TODO: nixos-generate-config doesn't detect bcache, so it had to be added manually.
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "ehci_pci" "usbhid" "usb_storage" "sd_mod" "bcache" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/96a73dda-ec0f-4271-a47e-25c51f45c189";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/76B5-00B7";
      fsType = "vfat";
    };

  swapDevices = [
    { device = "/var/swapfile"; size = 32*1024; }
  ];

  nix.maxJobs = lib.mkDefault 12;
}
