{ config, lib, pkgs, ... }:

let
  gitDaemonUser = "git-daemon";
  gitDaemonGroup = "git-daemon";
  gitoliteGroup = config.users.extraUsers."${config.services.gitolite.user}".group;
in
{
  services = {
    gitDaemon.enable = true;
    gitDaemon.basePath = config.services.gitolite.dataDir + "/repositories";
    gitDaemon.user = gitDaemonUser;
    gitDaemon.group = gitDaemonGroup;
    # only serve repositories containing 'git-daemon-export-ok' file
    gitDaemon.exportAll = false;
  };

  # The NixOS git-daemon service configures a 'git' user and group. This cause
  # a conflict because we've assigned this name to the gitolite hosting user.
  # The gitolite (hosting) user must be allowed to login to the system, whereas
  # the git-daemon user doesn't need that. Also, git-daemon never needs to
  # write anything to the git repositories, so using a separate user for
  # git-daemon with only read access seems like a good idea.
  users.extraUsers."${gitDaemonUser}" = {
    description = "Git Daemon User";
    uid = 506;
    group = gitDaemonGroup;
    extraGroups = [ gitoliteGroup ]; /* get read-only access to gitolite repos */
  };

  users.extraGroups."${gitDaemonGroup}" = {
    gid = 506;
  };

  # So that git doesn't die when it sees a '~' in /etc/gitconfig
  systemd.services.git-daemon.environment.HOME = "/var/empty";
}
