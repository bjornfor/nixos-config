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

  plugins = [
    "csapprox"
    "csv-vim"
    "editorconfig-vim"
    "fugitive"
    "fzf-vim"
    "fzfWrapper"
    "gundo-vim"
    "matchit-zip"
    "nerdcommenter"
    "taglist-vim"
    "vim-addon-nix"
    "vim-airline"
    "vim-gitgutter"
    "vim-speeddating"
  ];

  vimConfig = {
    customRC = builtins.readFile ./vimrc;
    vam.knownPlugins = pkgs.vimPlugins;
    vam.pluginDictionaries = [
      { names = plugins; }
    ];
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
