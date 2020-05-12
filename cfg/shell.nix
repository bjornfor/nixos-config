{ config, lib, pkgs, ... }:

{
  environment.shellAliases = {
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

  environment.interactiveShellInit = ''
    # A nix query helper function
    nq()
    {
      case "$@" in
        -h|--help|"")
          printf "nq: A tiny nix-env wrapper to search for packages in package name, attribute name and description fields\n";
          printf "\nUsage: nq <case insensitive regexp>\n";
          return;;
      esac
      nix-env -qaP --description \* | grep -i "$@"
    }

    # Edit the real configuration.nix file, not the /etc/nixos/configuration.nix
    # symlink. This fixes using Vim 'gf' to jump to relative file paths.
    en()
    {
        (cd /etc/nixos \
            && vim -c "set makeprg=sudo\ nixos-rebuild\ dry-build errorformat=error:\ %m\ at\ %f:%l:%c" "machines/$HOSTNAME/configuration.nix" \
            && (echo "Activate the new config? sudo nixos-rebuild ...?"
                echo " 1) switch"
                echo " 2) test"
                echo " q) quit"
                read -p "Your choice? [q] " ans
                case "$ans" in
                    1) action=switch;;
                    2) action=test;;
                    *) echo "quit"; exit 0;;
                esac
                sudo nixos-rebuild "$action"
               )
        )
    }

    export HISTCONTROL=ignoreboth   # ignorespace + ignoredups
    export HISTSIZE=1000000         # big big history
    export HISTFILESIZE=$HISTSIZE

    # Disable use of Ctrl-S/Ctrl-Q to stop/start process output. This frees up
    # those keys to do other stuff.
    stty stop ""
    stty start ""
  '';

  environment.sessionVariables = {
    NIX_AUTO_INSTALL = "1";
    EDITOR = "vim";
    VISUAL = "vim";
    LESS = "--ignore-case --quit-if-one-screen";
  };

  programs.bash.enableCompletion = true;

  programs.bash.interactiveShellInit = ''
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

    shopt -s histappend             # append to history, don't overwrite it

    # Add completion for my taskwarrior "t" alias. Hm, we must force load the
    # original completion file first, or else the _task function will not be
    # defined.
    source "${pkgs.taskwarrior}/share/bash-completion/completions/task.bash"
    complete -o nospace -F _task t

    # FZF fuzzy finder configuration
    ${if lib.versionOlder lib.version "20.03" then
      # git completion is broken when fzf/.../completion.bash is sourced since
      # nixpkgs commit dc45fc4c ("Install git’s bash completion so that it is
      # loaded on demand"), i.e. NixOS 20.03. Workaround: instead of "cd
      # **<TAB>", just "cd <ctrl-t>". (Perhaps it has other features too, but
      # I'm not using them.)
      ''
        # Try "cd **<TAB>"
        source "${pkgs.fzf}/share/fzf/completion.bash"
      ''
      else ""
    }
    # Try ctrl-r, ctrl-t or alt-c
    source "${pkgs.fzf}/share/fzf/key-bindings.bash"
  '';

  programs.bash.promptInit = ''
    eval "$(${pkgs.starship}/bin/starship init bash)"
  '';
}
