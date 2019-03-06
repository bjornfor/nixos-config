# Wrapped tmux with custom tmux.conf (no global state).

{ pkgs }:

let
  plugins = with pkgs.tmuxPlugins; [
    resurrect
    continuum  # depends on resurrect, so must be after it
  ];

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

      # Configure plugins
      echo "" >> "$out"
      # tmux-continuum config
      # Last saved environment is automatically restored when tmux is started.
      echo "set-option -g @continuum-restore 'on'" >> "$out"

      # Install plugins
      echo "" >> "$out"
      echo "# Plugins" >> "$out"
      echo '${pkgs.lib.concatMapStrings (x: "run-shell ${x.rtp}\n") plugins}' >> "$out"
    '';

  tmuxWithConf = pkgs.writeScriptBin "tmux" ''
    #!${pkgs.bash}/bin/bash
    export PATH="''${PATH}''${PATH:+:}${with pkgs; lib.makeBinPath [ pythonPackages.powerline xclip ]}"
    exec "${pkgs.tmux}/bin/tmux" -f "${fullTmuxConf}" "$@"
  '';

  tmuxSourceConf = pkgs.writeScriptBin "tmux-source-conf" ''
    #!${pkgs.bash}/bin/bash
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
    cp "${tmuxSourceConf}/bin/tmux-source-conf" "$out/bin/tmux-source-conf"
  '';
}
