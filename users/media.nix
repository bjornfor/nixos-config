{ config, lib, pkgs, ... }:

{
  users.extraUsers = {
    media = {
      description = "Media user";
      uid = 1001;
      extraGroups = [
        "cdrom"
        "transmission"
        "wheel"
      ];
      isNormalUser = true;
      initialPassword = "media";
    };
  };
}
