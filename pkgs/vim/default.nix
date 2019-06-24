# Custom Vim package with bundled plugins and .vimrc.
#
# Measure Vim startup time, to see which plugins slow it down:
# $ time vim --startuptime /dev/stdout +q
#
# Some vim and neovim differences:
# Startup time:
#   nvim: ~450 ms
#   vim:  ~250 ms
# Easy to map Alt+<key>:
#   nvim: yes
#   vim: no
# Whether :!COMMAND is tty-capable (no means: cannot run 'tig' nor 'git add
# -p' and 'git df' is without colors):
#   nvim: no
#   vim: yes

{ pkgs, useNeovim ? true }:

let
  vimConfig = {
    customRC = builtins.readFile ./vimrc;
    packages.myVimPackage = with pkgs.vimPlugins; {
      # loaded on launch
      start = [
        csapprox
        csv-vim
        editorconfig-vim
        fugitive
        fzf-vim
        fzfWrapper
        gundo-vim
        LanguageClient-neovim  # also supports vim >= 8.0
        matchit-zip
        nerdcommenter
        taglist-vim
        vim-airline
        vim-gitgutter
        vim-nix
        vim-speeddating
        vim-tmux-navigator
      ];
      # manually loadable by calling `:packadd $plugin-name`
      opt = [ /* ... */ ];
      # To automatically load a plugin when opening a filetype, add vimrc lines
      # like:
      # autocmd FileType php :packadd phpCompletion
    };
  };
in

if useNeovim then
  pkgs.neovim.override {
    vimAlias = true;
    configure = vimConfig;
  }
else
  pkgs.vim_configurable.customize {
    name = "vim";
    vimrcConfig = vimConfig;
  }
