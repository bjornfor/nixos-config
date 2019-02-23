# Wrapped tmux with custom tmux.conf (no global state).

{ pkgs }:

let
  fullTmuxConf = pkgs.runCommand "tmux.conf"
    { # Variables to be substituted in tmux.conf
      pythonPackages_powerline = pkgs.pythonPackages.powerline;
    }
    ''
      cp ${./tmux.conf} "$out"
      substituteAllInPlace "$out"

      # Assert that there are no remaining @metaVars@.
      if grep -rn "@[a-z][a-zA-Z0-9_-]*@" "$out"; then
          echo "error: found one or more unpatched @metaVars@"
          exit 1
      fi
    '';

  tmuxWithConf = pkgs.writeShellScriptBin "tmux" ''
    export PATH="''${PATH}''${PATH:+:}${pkgs.pythonPackages.powerline}/bin"
    exec "${pkgs.tmux}/bin/tmux" -f "${fullTmuxConf}" "$@"
  '';

  tmuxSourceConf = pkgs.writeShellScriptBin "tmux-source-conf" ''
    # Helper script to source the new tmux.conf without global state (only
    # $PATH lookup).
    "${pkgs.tmux}/bin/tmux" source-file "${fullTmuxConf}"
    "${pkgs.tmux}/bin/tmux" display-message "sourced ${fullTmuxConf}"
  '';
in
pkgs.symlinkJoin {
  name = "${pkgs.tmux.name}-with-config";
  paths = [ pkgs.tmux.all ];
  postBuild = ''
    rm "$out/bin/tmux"
    cp "${tmuxWithConf}/bin/tmux" "$out/bin"
    cp "${tmuxSourceConf}/bin/tmux-source-conf" "$out/bin/.tmux-source-conf"
  '';
}
