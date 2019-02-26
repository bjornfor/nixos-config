# Custom Vim package with bundled plugins and .vimrc.
#
# Measure Vim startup time, to see which plugins slow it down:
# $ time vim --startuptime /dev/stdout +q

{ pkgs }:

let
  # Startup times:
  # nvim: ~450 ms
  # vim:  ~250 ms
  useNeovim = false;

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
        matchit-zip
        nerdcommenter
        taglist-vim
        #vim-addon-nix  # fails to load unless plugins are managed by VAM?
        vim-airline
        vim-gitgutter
        vim-speeddating
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
