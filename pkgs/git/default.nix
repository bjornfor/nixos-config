# Wrapped git with custom gitconfig (no global state).

{ pkgs }:

let
  # There doesn't seem to be a -f path/to/gitconfig option. Workaround: pass
  # all options using -c section.key=value.
  # TODO: Suggest upstream to add option to read custom config file that
  # disables reading the global files (/etc/gitconfig, ~/.gitconfig).
  gitConfig = {
    core = {
      editor = "vim";
      excludesfile = "~/.gitignore";
    };
    color = {
      ui = "auto";
    };
    alias = {
      st = "status";
      df = "diff";
      ci = "commit";
      co = "checkout";
      wc = "whatchanged";
      br = "branch";
      f = "fetch";
      a = "add";
      l = "log";
      lga = "log --graph --pretty=oneline --abbrev-commit --decorate --all";
      rup = "remote update -p";
      # Working with github pull-requests:
      #   - git pullify  # just once
      #   - git fetch
      #   - git checkout pr/PULL_REQUEST_NUMBER
      pullify = "config --add remote.origin.fetch '+refs/pull/*/head:refs/remotes/origin/pr/*'";
      incoming = "log ..@{u}";
      outgoing = "log @{u}..";
      # "git serve" is from https://gist.github.com/datagrok/5080545
      serve = "daemon --verbose --export-all --base-path=.git --reuseaddr --strict-paths .git/";
      suir = "submodule update --init --recursive";
    };
    sendemail = {
      smtpserver = "/run/current-system/sw/bin/msmtp";
    };
    # TODO: How to specify this gitconfig snippet "[diff "word"]\ntextconv=..."?
    ##"diff\\ \\\"word\\\"" = {
    #"diff word" = {
    #  textconv = "antiword";
    #};
    push = {
      default = "simple";
    };
  };

  argsFromConf = conf:
    let
      inherit (pkgs.lib) concatStringsSep flatten mapAttrsToList;
      genArg = section: sattrs:
        mapAttrsToList (n: v: "-c \"${section}.${n}=${v}\"") sattrs;
    in
      concatStringsSep " " (flatten (mapAttrsToList genArg (conf)));
    
  gitWithConf = pkgs.writeScriptBin "git" ''
    #!${pkgs.bash}/bin/bash
    exec "${pkgs.gitFull}/bin/git" ${argsFromConf gitConfig} "$@"
  '';

in
pkgs.symlinkJoin {
  name = "${pkgs.gitFull.name}-with-config";
  paths = [ pkgs.gitFull.all ];
  postBuild = ''
    rm "$out/bin/git"
    cp "${gitWithConf}/bin/git" "$out/bin"
  '';
}
