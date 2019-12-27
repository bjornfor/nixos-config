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
    customRC =
      let
        # get the ./src/ tree from the source tarball of a rustc package
        mkRustSrcPath = rustc:
          pkgs.runCommand "${rustc.name}-srcpath" { preferLocalBuild = true; } ''
            mkdir -p "$out"
            tar --strip-components=2 -xf "${rustc.src}" -C "$out" "${rustc.name}-src"
          '';
      in
        (builtins.readFile ./vimrc) + ''
          let $RUST_SRC_PATH = '${mkRustSrcPath pkgs.rustc}'
        '';
    packages.myVimPackage = with pkgs.vimPlugins; {
      # loaded on launch
      start = [
        csapprox
        csv-vim
        deoplete-nvim
        editorconfig-vim
        fugitive
        fzf-vim
        fzfWrapper
        gundo-vim
        LanguageClient-neovim  # also supports vim >= 8.0
        matchit-zip
        nerdcommenter
        nerdtree
        taglist-vim
        vim-airline
        vim-eunuch
        vim-gitgutter
        vim-nix
        vim-racer
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
