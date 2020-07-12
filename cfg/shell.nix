{ config, lib, pkgs, ... }:

{
  environment.interactiveShellInit = ''
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

  programs.bash.interactiveShellInit = ''
    # Add completion for my taskwarrior "t" alias. Hm, we must force load the
    # original completion file first, or else the _task function will not be
    # defined.
    source "${pkgs.taskwarrior}/share/bash-completion/completions/task.bash"
    complete -o nospace -F _task t
  '';
}
