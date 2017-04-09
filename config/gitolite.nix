{ config, lib, pkgs, ... }:

let
  # TODO: add group to the upstream gitolite.nix module
  # TODO: remove hash from the initial admin key committed to the gitolite-admin repo (also gitolite.nix module)
  gitoliteGroup = "git";
in
{
  # Gitolite defaults to UMASK 0077. After the initial setup, open
  # ${dataDir}/.gitolite.rc and make that 0027 for group readability. This is
  # needed for webserver/cgit.

  # Tips for cgit + gitolite + lighttpd configuration:
  # https://joel.porquet.org/wiki/hacking/cgit_gitolite_lighttpd_archlinux/

  services = {
    gitolite = {
      enable = true;
      dataDir = "/srv/git";
      # Initial admin key (ssh)
      adminPubkey = with import ../misc/ssh-keys.nix; bfo_at_mini;
      user = "git";
    };
  };

  systemd.services.gitolite-init = {
    serviceConfig.PermissionsStartOnly = true;
    preStart = ''
      chmod a+rx /srv
    '';
  };

  users.extraGroups."${gitoliteGroup}".gid = 505;
  users.extraUsers."${config.services.gitolite.user}".group = gitoliteGroup;
}
