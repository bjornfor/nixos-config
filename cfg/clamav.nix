{ config, lib, pkgs, ... }:

{
  services = {
    clamav = {
      updater.enable = true;
      updater.frequency = 1;  # number of checks per day
    };
  };
}
