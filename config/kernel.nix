{ config, lib, pkgs, ... }:

{
  # Select Linux version
  boot.kernelPackages = pkgs.linuxPackages;
}

