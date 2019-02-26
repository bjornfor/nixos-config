"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Bjørn Forsman's .vimrc file v0.7
"
" Plugins are managed with vim-plug:
"   https://github.com/junegunn/vim-plug
"
" Run :PlugInstall to install plugins.
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if has('nvim')
    let local_path_to_vim_plug = "~/.local/share/nvim/site/autoload/plug.vim"
else
    let local_path_to_vim_plug = "~/.vim/autoload/plug.vim"
endif

if !filereadable(expand(local_path_to_vim_plug))
    echo "vim-plug not found. Installing it..."
    call system("curl -fLo " . local_path_to_vim_plug . " --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim")
    echo "...done. Now run :PlugInstall to install all plugins."
endif

" Specify a directory for plugins
" - For Neovim: ~/.local/share/nvim/plugged
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')

" Make sure you use single quotes.
" Tracking down slow Vim startup (caused by too many plugins):
"   time vim --startuptime /dev/stdout +q
Plug 'honza/vim-snippets'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
"Plug 'MarcWeber/vim-addon-local-vimrc'  " error
"Plug 'MarcWeber/vim-addon-nix'          " error
Plug 'mfukar/robotframework-vim'
Plug 'vim-ruby/vim-ruby'
Plug 'vim-scripts/asciidoc.vim'
Plug 'vim-scripts/AutoTag'
Plug 'vim-scripts/bnf.vim'
Plug 'vim-scripts/CCTree'
Plug 'vim-scripts/CSApprox'
Plug 'vim-scripts/cscope_macros.vim'
Plug 'vim-scripts/csv.vim'
Plug 'vim-scripts/delimitMate.vim'
Plug 'vim-scripts/DetectIndent'
Plug 'vim-scripts/DrawIt'
Plug 'vim-scripts/EasyGrep'
Plug 'vim-scripts/ebnf.vim'
Plug 'vim-scripts/editorconfig-vim'
" Plug 'vim-scripts/EvalSelection'
Plug 'vim-scripts/fugitive.vim'
Plug 'vim-scripts/Gundo'
Plug 'vim-scripts/headerguard'
Plug 'vim-scripts/indenthaskell.vim'
Plug 'vim-scripts/indentpython.vim--nianyang'
Plug 'vim-scripts/javacomplete'
Plug 'vim-scripts/matchit.zip'
Plug 'vim-scripts/Mustang2'
Plug 'vim-scripts/pydoc.vim'
Plug 'vim-scripts/python_match.vim'
Plug 'vim-scripts/rails.vim'
Plug 'vim-scripts/repeat.vim'
Plug 'vim-scripts/speeddating.vim'
Plug 'vim-scripts/surround.vim'
Plug 'vim-scripts/taglist-plus'
Plug 'vim-scripts/The-NERD-Commenter'
"Plug 'vim-scripts/The-NERD-tree'
Plug 'vim-airline/vim-airline'
Plug 'airblade/vim-gitgutter'
Plug 'vim-scripts/wmgraphviz'

" Initialize plugin system
call plug#end()

" Plugin notes:
" * DetectIndent must be hooked up: autocmd BufReadPost * :DetectIndent
" * snipMate messes somewhat with autocomplete (<C-o> and <C-u>) so
"   that multiple TAB keys do not cycle through the list. One can still use
"   <C-n>/<C-p> though...
"


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Generic stuff
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
filetype plugin indent on

syntax on

" look for 'tags' in current directory and work up the tree towards root until
" one is found
set tags+=tags;/

" leader is default '\', but it's difficult to reach
let mapleader = " "
" wmgraphviz plugin uses <LocalLeader>, just set them to the same value
let maplocalleader = " "

colorscheme default
set bg=light

set hidden	" hide abandoned buffers. This option removes the demand for buffers to be 'unmodified' when left. This is very handy when working with lots of buffers!
"set ts=4	" tabstop, number of spaces for tab character, defaults to 8
"set sw=4	" shiftwidth, number of spaces for autoindent, defaults to 8
set showmode	" status line displays 'insert' or 'visual' when not in normal mode
set showcmd
set undofile
" Trying to copy text in Vim with clipboard=unnamedplus over an SSH connection
" with X forwarding fails with:
"   BadAccess (attempt to access private resource denied)
"   Vim: Got X error
"   Vim: Finished.
" So only use unnamedplus for non-SSH sessions.
" Alternatively, assuming you trust the host, clipboard=unnamedplus can be set
" unconditionally if running with `ssh -Y host1` or ~/.ssh/config contains:
"   Host host1
"   ForwardX11Trusted yes
if ! $SSH_CONNECTION
    set clipboard=unnamedplus
endif
"set wildmenu	" when tab'ing on the vim command line, a menu appear just above the command line
"To have the completion behave similarly to a shell, i.e. complete only up to
"the point of ambiguity (while still showing you what your options are), also
"add the following:
set wildmode=list:longest
" Or use a combination:
"set wildmode=list:longest,full
set ruler	" show the cursor position all the time
"set autoindent " uses the indent from prev line
"set cindent	" smarter indent
"set showmatch	" briefly jump to matching bracket when the cursor is on a bracket
" ask what to do instead of just failing (e.g. when :q notices there are
" unsaved changes and refuses to quit):
"set confirm
set mouse=a " allow using the mouse to change marker position and enter visual mode
set laststatus=2 "always show status bar/line
"set fdm=indent " fold method: fold sections based on indent level
"set foldlevel=3
"set history=100 " how many command lines to store?
"set lines=51
"set columns=80
" joinspaces: use two spaces after '.' when joining a line (or not: nojs)
set nojs
set modeline " read modelines
"set cursorline	" highlight the line the cursor is on
set hlsearch    " highlight search. Turn off with :noh{lsearch}
set incsearch   " incremental search, i.e. search while typing
set ic          " ignore case in searches
set smartcase   " only care about case if search word uses upper case (use with ignorecase)
set scrolloff=1
set visualbell

" This makes backspace behave like everyone expects it to. Needed on Windows
" and some Linux distros.
set backspace=indent,eol,start

" fix for the annoying purple background "shining through" on ubuntu
" Neovim doesn't have 'ttyscroll' ("E518: Unknown option: ttyscroll=0")
if !has('nvim')
    set ttyscroll=0
endif

" Use ripgrep if available (it's fast)
if executable("rg")
    set grepprg=rg\ --vimgrep
    set grepformat^=%f:%l:%c:%m
endif

" 'sudo apt-get install wnorwegian' for /usr/share/dict/bokmaal
set dictionary+=/usr/share/dict/words
" Get mthesaur.txt:
"   wget http://www.gutenberg.org/dirs/etext02/mthes10.zip
"   unzip mthes10.zip
"   mv mthesaur.txt ~/.mthesaur.txt
set thesaurus+=~/.mthesaur.txt
" Vim integrated spell support:
" :set[local] spell spelllang=nb   # will download spell files (to $HOME) if needed
" :set[local] spell spelllang=en_us  # change language (and region)
" :set[local] nospell  # turn off spelling (highlighting)
" Type 'z=' when on a misspelled word to get suggestions

" Direct backup, swap and undo files away from $PWD. Use trailing '//' to
" ensure no filename conflict; Vim creates files where '%' is used in place of
" the directory separator.
set backupdir=~/.vim/backup//
set directory=~/.vim/swap//
set undodir=~/.vim/undo//
" Create the above directories if needed
if !isdirectory(expand("~/.vim/backup"))
    call mkdir(expand("~/.vim/backup"), "p")
endif
if !isdirectory(expand("~/.vim/swap"))
    call mkdir(expand("~/.vim/swap"), "p")
endif
if !isdirectory(expand("~/.vim/undo"))
    call mkdir(expand("~/.vim/undo"), "p")
endif

"hi SpecialKey guifg=bg " hide all special characters, e.g. dos newlines ^M

"autocmd BufWinLeave *.[ch] mkview
"autocmd BufWinEnter *.[ch] silent loadview

" let vim recognize Sup (MUA) temp files
autocmd BufNewFile,BufRead *sup.*-mode set ft=mail

autocmd BufNewFile,BufRead *.bnf set ft=bnf
autocmd BufNewFile,BufRead *.ebnf set ft=ebnf
" .gv is the new GraphViz/dot filename extension
autocmd BufNewFile,BufRead *.gv set ft=dot

" These options seem to be needed for extracting C structure member info
" when used with local variables:
"   --c-kinds=+l
"   --fields=+a
"   --extra=+q
nmap <F12> :!ctags -R --c++-kinds=+pl --c-kinds=+pl --fields=+iaS --extra=+q .<CR>\|:!cscope -R -b<CR>\|:cs r<CR><CR>

" SingleCompile plugin
nmap <F8> :SCCompile<CR>
nmap <F9> :SCCompileRun<CR>

" Code completion tips (from http://vim.wikia.com/wiki/VimTip1608):
"
" mkdir ~/.vim/tags
" cd ~/.vim/tags
" ctags -R --c++-kinds=+p --fields=+iaS --extra=+q --language-force=C++ -f cpp /path/to/cpp_src  # or /usr/include/c++/VERSION/ ?
" ctags -R --c++-kinds=+p --fields=+iaS --extra=+q --language-force=C++ -f gl /usr/include/GL/   # for OpenGL
" ctags -R --c++-kinds=+p --fields=+iaS --extra=+q --language-force=C++ -f sdl /usr/include/SDL/ # for SDL
" ctags -R --c++-kinds=+p --fields=+iaS --extra=+q --language-force=C++ -f qt /usr/include/Qt* # for Qt
" ctags -R --c++-kinds=+p --fields=+iaS --extra=+q --language-force=C++ -f directfb /usr/include/directfb* # for directfb
"
" load the needed tag files
"set tags+=~/.vim/tags/cpp
"set tags+=~/.vim/tags/gl
"set tags+=~/.vim/tags/sdl
"set tags+=~/.vim/tags/qt
"set tags+=~/.vim/tags/directfb

" toggle invisible chars
noremap <Leader>i :set list!<CR>

nnoremap <Leader><Space> :noh<CR>

" Bash like keys for the command line
cnoremap <C-A> <Home>
cnoremap <C-E> <End>

" vimperator-like keyboard shortcuts for jumping to next/previous buffers
nmap <C-n> :bn<CR>
nmap <C-p> :bp<CR>

" search will center on the line it's found in
"map N Nzz
"map n nzz

" <Space> by default behaves like 'l', make it more useful
"nmap <Space> <C-f>		" scroll one screenful down
"nmap <Space> za		" toggle folds

" :%s for search and replace is hard to type
" lets map them to gs...
"nmap gs :%s/
" But this is needed more often
nmap gs :Gstatus<CR>
nmap gd :Gdiff<CR>

map <Leader>m :up<CR>:make<CR>
"nmap <C-a> ggVG	" ctrl+a is normally used for incrementing the number under the cursor

" Insert new line without going into insert mode
"nmap <S-Enter> O<Esc>		" insert above
"nmap <Enter> o<Esc>		" insert below

" Easier navigation with C compilation errors, grep searches and tags.
" Note: After finding the :cw command, I think there is not much use in
" these mappings anymore...
"nmap <F5> :cp<CR>
"nmap <F6> :cn<CR>
"nmap <F7> :tp<CR>
"nmap <F8> :tn<CR>
"nmap <Up> :cp<CR>
"nmap <Down> :cn<CR>

" Make single-quote act as back-tick, because single-quote is easier to reach
" on my keyboard. Now, typing '. gets us back to the last edit location, both
" line *and column*.
map ' `

" scroll faster
nnoremap <C-e> 2<C-e>
nnoremap <C-y> 2<C-y>

" Smart way to move between windows.
" It's somewhat confusing when combined with tmux, so disable for now.
"map <C-j> <C-W>j
"map <C-k> <C-W>k
"map <C-h> <C-W>h
"map <C-l> <C-W>l

" easier working with split windows
"map <C-J> <C-W>j<C-W>_
"map <C-K> <C-W>k<C-W>_
"set wmh=0

"" maps for jj/jk to act as escape
"inoremap jj <Esc>
"cnoremap jj <C-c>
inoremap jk <Esc>
cnoremap jk <C-c>
" act the same if shift is pressed
"inoremap JJ <Esc>
"cnoremap JJ <C-c>
inoremap JK <Esc>
cnoremap JK <C-c>
""For visual mode, just use "v" to toggle it on and off:
"vno v <Esc>

" n is for normal mode
nnoremap Q gqap
" v is for visual mode.
vnoremap Q gq

nmap Y y$

" edit binary files (xxd is normally included in base installs)
nmap <Leader>hon :%!xxd<CR>
nmap <Leader>hof :%!xxd -r<CR>

map <Leader>n :NERDTreeToggle<CR>

nnoremap <Leader>g :YcmCompleter GoToDefinitionElseDeclaration<CR>

" This is for working across multiple xterms and/or gvims
map <Leader>w :w! ~/.vimxfer<CR>
map <Leader>r :r ~/.vimxfer<CR>
" Append
map <Leader>a :w! >>~/.vimxfer<CR>

autocmd FileType haskell map <buffer> <F5> :update<CR>:!runghc %<CR>
autocmd FileType haskell setlocal sw=4 sts=4 expandtab

autocmd FileType ruby setlocal sw=2 sts=2 expandtab

autocmd Filetype java setlocal omnifunc=javacomplete#Complete

autocmd FileType python map <buffer> <F5> :update<CR>:!python %<CR>

autocmd FileType html setlocal sw=4 sts=4 expandtab
autocmd FileType xhtml setlocal sw=4 sts=4 expandtab
autocmd FileType nix setlocal sw=2 sts=2 expandtab iskeyword+=-
autocmd FileType robot setlocal sw=4 sts=4 expandtab
autocmd FileType vim setlocal sw=4 sts=4 expandtab
autocmd FileType gitolite setlocal sw=4 sts=4 expandtab
autocmd FileType sh setlocal sw=4 sts=4 expandtab


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" GVim stuff
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has('gui_running')
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" OS Specific
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if has("unix")
    " easy .vimrc access
    nmap <Leader>s :source $HOME/.vimrc<CR>
    nmap <Leader>e :edit $HOME/.vimrc<CR>
    " source .vimrc when written - FIXME: messes up colorscheme!
    "autocmd BufWritePost .vimrc source %
    let g:clipbrdDefaultReg = '+'
endif

if has("gui_win32")
    " settings for windows goes here

    " easy _vimrc access
    nmap <Leader>s :source $HOME/_vimrc<CR>
    nmap <Leader>e :edit $HOME/_vimrc<CR>
endif

if has("mac")
    " settings for mac goes here
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Settings related to plugins
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get gvim colorschemes in vim (the CSApprox plugin is required).
" When the CSApprox plugin is installed we just need to tell vim that
" we have a terminal with lots of colors.
if &term =~ '^\(xterm\|screen\|screen-bce\)$'
    set t_Co=256
endif

" easy mappings for the taglist plugin (vim-addons install taglist)
nnoremap <silent> <Leader>t :TlistToggle<CR>

" fzf.vim
map <Leader>f :Files<CR>
map <Leader>b :Buffers<CR>
" Use the whole screen
let g:fzf_layout = { 'down': '~100%' }

" (snipmate) see :h g:snips_author
let g:snips_author = 'Bjørn Forsman'

" NERDCommenter
" Add (and remove) spaces inside comments so that we get this:
"   /* int foo=2; */
" instead of this (default):
"   /*int foo=2;*/
let NERDSpaceDelims = 1
" toggle comments in visual mode with '*'
vmap * <Leader>ci

" Enable Asciidoc syntax highlighting on *.txt files (need the asciidoc plugin)
"autocmd BufNewFile,BufRead *.txt set ft=asciidoc
autocmd BufNewFile,BufRead *.asciidoc setlocal ft=asciidoc
" RoboMachine is Robot Framework syntax
autocmd BufNewFile,BufRead *.robomachine setlocal ft=robot

" TODO: revisit rope/ropevim
"let ropevim_vim_completion=1
"function! TabWrapperRope()
"    if strpart(getline('.'), 0, col('.')-1) =~ '^\s*$'
"        return "\<Tab>"
"    else
"        return "\<C-R>=RopeCodeAssistInsertMode()\<CR>"
"    endif
"endfunction
"
"imap <Tab> <C-R>=TabWrapperRope()<CR>

"" automatically open and close the popup menu / preview window
"au CursorMovedI,InsertLeave * if pumvisible() == 0|silent! pclose|endif
"set completeopt=menuone,menu,longest,preview
set completeopt=menuone

" AutoTag
"let g:autotagCtagsCmd="ctags --c++-kinds=+p --c-kinds=+l --fields=+iaS --extra=+q"

" delimitMate
" Disable for text files
au Filetype text let b:loaded_delimitMate = 1
" See 'help delimitMate_eol_marker'
"au FileType c,cpp,java,perl let b:delimitMate_eol_marker = ";"
let delimitMate_expand_cr = 1
let delimitMate_expand_space = 1
"let delimitMate_autoclose = 0

" EditorConfig
let g:EditorConfig_exclude_patterns = ['fugitive://.*', 'scp://.*']


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Host specific
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if filereadable(expand("~/.vimrc.local"))
    source ~/.vimrc.local
endif

"if hostname() == "foo"
"    " do something
"endif

if hostname() == "timmons"
    " for the vim wiki:
    set tags+=/media/raid/bjornfor/projects/vim-wiki/tags
    autocmd BufWritePost /media/raid/bjornfor/projects/vim-wiki/* :helptags /media/raid/bjornfor/projects/vim-wiki
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Python stuff
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has("python")
python << EOF
def setPythonPath():
    import os
    import sys
    import vim
    vim.command(r"setlocal path-=/usr/include")  # remove C/C++ header path
    for p in sys.path:
        if os.path.isdir(p):
            vim.command(r"setlocal path+=%s" % (p.replace(" ", r"\ ")))
EOF
autocmd FileType python python setPythonPath()
" ipdb is the IPython debugger: pip install ipdb
autocmd FileType python nmap <Leader>pdb oimport ipdb; ipdb.set_trace()<Esc>^
endif " has("python")

autocmd FileType python setlocal sw=4 sts=4 et

" :make invokes pylint and errors are directed to offending line.
" TODO: try pylint/pyunit/python compilers
"au FileType python compiler pylint

" Change pylint behaviour (see pylint.vim for doc):
"let g:pylint_onwrite = 0
"let g:pylint_show_rate = 0
let g:pylint_cwindow = 0

" Create a Python tags file:
"   ctags -R -f ~/.vim/tags/python.ctags /usr/lib/python2.6
" and then use it in Vim:
"set tags+=~/.vim/tags/python.ctags
