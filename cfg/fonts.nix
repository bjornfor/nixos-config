{ config, lib, pkgs, ... }:

{
  fonts.fonts = with pkgs; [
    #python3Packages.powerline  # looks ok
    powerline-fonts            # looks better
  ];
}
