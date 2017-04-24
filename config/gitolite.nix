{ config, lib, pkgs, ... }:

let
  # TODO: add group to the upstream gitolite.nix module
  # TODO: remove hash from the initial admin key committed to the gitolite-admin repo (also gitolite.nix module)
  gitoliteGroup = "git";
in
{
  # Gitolite defaults to UMASK 0077. After the initial setup, open
  # ${dataDir}/.gitolite.rc and make that 0027 for group readability. This is
  # needed for webserver/cgit. Already created directories and files and can be
  # made group accessible by running `chmod -R g+rX ...`.

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

  # Creating /srv requires root privileges. The gitolite-init service itself
  # runs as unprivileged user. Use this helper service to create the needed
  # directories.
  systemd.services.gitolite-init-setup-srv = {
    description = "Create /srv Directory For Gitolite";
    requiredBy = [ "gitolite-init.service" ];
    before = [ "gitolite-init.service" ];
    script = ''
      mkdir -p /srv
      chmod a+rx /srv
    '';
    serviceConfig.Type = "oneshot";
  };

  users.extraGroups."${gitoliteGroup}".gid = 505;
  users.extraUsers."${config.services.gitolite.user}".group = gitoliteGroup;
}
