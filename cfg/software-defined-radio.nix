{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gnuradio-with-packages
    gqrx
    kalibrate-rtl
    rtl-sdr
  ];

  # Uncomment to compose environments with nix-env (alternative to
  # gnuradio-with-packages).
  #environment.profileRelativeEnvVars = {
  #  GRC_BLOCKS_PATH = [ "/share/gnuradio/grc/blocks" ];
  #};

  services.udev.packages = with pkgs; [
    rtl-sdr
  ];
}
