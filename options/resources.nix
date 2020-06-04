{ config, lib, pkgs, ... }:

{
  options.local = {
    resources = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Arbitrary shared resources to pass around in the NixOS configuration.";
    };
  };
}
