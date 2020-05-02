{ config, lib, pkgs, ... }:

{
  environment.shellAliases = {
    ".." = "cd ..";
    "..." = "cd ../..";
    "..2" = "cd ../..";
    "..3" = "cd ../../..";
    "..4" = "cd ../../../..";
    "t" = "task";
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
    PROMPT_COMMAND+="_append_history;"

    shopt -s histappend             # append to history, don't overwrite it

    # Add completion for my taskwarrior "t" alias. Hm, we must force load the
    # original completion file first, or else the _task function will not be
    # defined.
    source "${pkgs.taskwarrior}/share/bash-completion/completions/task.bash"
    complete -o nospace -F _task t

    # FZF fuzzy finder configuration
    # Try "cd **<TAB>"
    source "${pkgs.fzf}/share/fzf/completion.bash"
    # Try ctrl-r, ctrl-t or alt-c
    source "${pkgs.fzf}/share/fzf/key-bindings.bash"
  '';

  # Show git info in bash prompt and display a colorful hostname if using ssh.
  programs.bash.promptInit = ''
    export GIT_PS1_SHOWDIRTYSTATE=1
    source ${pkgs.gitAndTools.gitFull}/share/git/contrib/completion/git-prompt.sh

    __prompt_color="1;32m"
    # Alternate color for hostname if the generated color clashes with prompt color
    __alternate_color="1;33m"
    __hostnamecolor="$__prompt_color"
    # If logged in with ssh, pick a color derived from hostname
    if [ -n "$SSH_CLIENT" ]; then
      __hostnamecolor="1;$(${pkgs.nettools}/bin/hostname | od | tr ' ' '\n' | ${pkgs.gawk}/bin/awk '{total = total + $1}END{print 30 + (total % 6)}')m"
      # Fixup color clash
      if [ "$__hostnamecolor" = "$__prompt_color" ]; then
        __hostnamecolor="$__alternate_color"
      fi
    fi

    __red="1;31m"

    PS1='\n$(ret=$?; test $ret -ne 0 && printf "\[\e[$__red\]$ret\[\e[0m\] ")\[\e[$__prompt_color\]\u@\[\e[$__hostnamecolor\]\h \[\e[$__prompt_color\]\w$(__git_ps1 " [git:%s]")\[\e[0m\]\n$ '
  '';
}
