{ pkgs, lib, ... }:

{
  programs.bash = {
    enable = true;
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    historyFileSize = 1000000;
    historySize = 1000000;  # big big history
    initExtra = ''
      # Continuously save history.
      # Use "history -n" to load global history into the shell on demand. This is
      # not on by default because it'd be pretty confusing if arrow-up shows
      # stuff from _other_ sessions.
      _append_history()
      {
          # preserve exit code
          local ret=$?
          history -a
          return "$ret"
      }
      # Add trailing semi-colon, if needed. (Two consecutive semi-colons is an
      # error.)
      if [ "''${PROMPT_COMMAND}" != "" ] && [ "''${PROMPT_COMMAND: -1}" != ";" ]; then
          PROMPT_COMMAND+=";"
      fi
      PROMPT_COMMAND+="_append_history;"
    '';
    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
      "..2" = "cd ../..";
      "..3" = "cd ../../..";
      "..4" = "cd ../../../..";
      g = "git";
      grep = "grep --color=auto";
      t = "task";
      tmuxm = "tmux new -A -s main";
    };
    shellOptions = [
      "histappend"
    ];
  };

  programs.fzf.enable = true;

  programs.starship.enable = true;
}
