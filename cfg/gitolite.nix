{ config, lib, pkgs, ... }:

{
  # Tips for cgit + gitolite + lighttpd configuration:
  # https://joel.porquet.org/wiki/hacking/cgit_gitolite_lighttpd_archlinux/

  services = {
    gitolite = {
      enable = true;
      dataDir = "/srv/git";
      # Initial admin key (ssh)
      adminPubkey = with import ../misc/ssh-keys.nix; mini.bf.default;
      user = "git";
      group = "git";
      extraGitoliteRc = ''
        # Make dirs/files group readable, needed for webserver/cgit. (Default
        # setting is 0077.)
        $RC{UMASK} = 0027;

        $RC{GIT_CONFIG_KEYS} = '.*';

        # Allow creators of "wild repos" to delete their own repos.
        push( @{$RC{ENABLE}}, 'D' );
      '';
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
}
