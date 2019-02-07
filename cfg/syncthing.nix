{ config, lib, pkgs, ... }:

{
  services.syncthing = {
    enable = true;
    group = "syncthing"; # FIXME: NixOS defaults to "nogroup"
  };

  # Undo the 700 perms syncthing sets on /var/lib/syncthing on startup. Without
  # this the ACL entries for my user stop working.
  # See
  #  https://github.com/syncthing/syncthing/issues/3434
  #  https://github.com/NixOS/nixpkgs/issues/47513
  systemd.services.syncthing.postStart = lib.mkForce ''
    sleep 10
    chmod g+rx "${config.services.syncthing.dataDir}"
  '';

  # Enable debug trace to spot permission errors.
  #systemd.services.syncthing.environment.STTRACE = "scanner";
}
