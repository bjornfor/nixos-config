{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gnuradio-with-packages
    gqrx
    kalibrate-rtl
    rtl-sdr
  ];

  environment.profileRelativeEnvVars = {
    GRC_BLOCKS_PATH = [ "/share/gnuradio/grc/blocks" ];
  };

  services.udev.packages = with pkgs; [
    rtl-sdr
  ];
}
