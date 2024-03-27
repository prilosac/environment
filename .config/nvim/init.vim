filetype off " Turning off filetypes before plugin installs
""" Plug Install
if empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
""" Plug Config - Install Plugins
call plug#begin('~/.vim/plugged')
    Plug 'drewtempelmeyer/palenight.vim'
    Plug 'preservim/nerdtree'
    Plug 'junegunn/fzf'
    Plug 'junegunn/fzf.vim'
"   Plug 'Exafunction/codeium.vim', { 'branch': 'main' }
call plug#end()

""" General Configuration
let mapleader = " "
filetype plugin indent on

" show existing tab with 4 spaces width
set tabstop=4
" " when indenting with '>', use 4 spaces width
set shiftwidth=4
" " On pressing tab, insert 4 spaces
set expandtab
" " show relative line numbers
set relativenumber

set nocompatible
set ignorecase
set autoread
set mouse=a

""" highlight searches
set hlsearch

""" Enable folding
set foldmethod=indent
set foldlevel=99
set foldcolumn=2
set foldignore=
""" Enable folding with spacebar
nnoremap <space> za

""" Theme and syntax highlighting
syntax on
set background=dark
colorscheme palenight
" Enable true colors
if (has("termguicolors"))
    set termguicolors
endif

if &term =~ '256color'
	" disable Background Color Erase (BCE) so that color schemes
	" render properly when inside 256-color tmux and GNU screen.
	" see also http://snk.tuxfamily.org/log/vim-256color-bce.html
	set t_ut=
endif

"
" Configure lightline
let g:lightline = { 'colorscheme': 'palenight' }
let g:palenight_terminal_italics=1

" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc> ^[

" Configure FZF
let g:fzf_vim = {}
let g:fzf_vim.preview_window = ['right,50%,<70(up,40%)', 'ctrl-/']
nnoremap <Leader><Leader> :GFiles<CR>
nnoremap <Leader>fi       :Files<CR>
nnoremap <Leader>C        :Colors<CR>
nnoremap <Leader><CR>     :Buffers<CR>
nnoremap <Leader>fl       :Lines<CR>
nnoremap <Leader>ag       :Ag! <C-R><C-W><CR>
nnoremap <Leader>m        :History<CR>

""" Nerdtree setup
nnoremap <Leader>\ :NERDTreeToggle<Enter>
nnoremap <silent> <Leader>v :NERDTreeFind<CR>

" Remove all trailing whitespace by pressing F5
nnoremap <F5> :let _s=@/<Bar>:%s/\s\+$//e<Bar>:let @/=_s<Bar><CR>

autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
" Start NERDTree. If a file is specified, move the cursor to its window.
autocmd StdinReadPre * let s:std_in=1
"autocmd VimEnter * NERDTree | if argc() > 0 || exists("s:std_in") | wincmd p | endif  
"
