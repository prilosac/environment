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

""" Theme and syntax highlighting
syntax on
set background=dark
colorscheme palenight
" Enable true colors
if (has("termguicolors"))
    set termguicolors
endif
"
" Configure lightline
let g:lightline = { 'colorscheme': 'palenight' }
let g:palenight_terminal_italics=1

" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc> ^[

""" Nerdtree setup
nnoremap <Leader>\ :NERDTreeToggle<Enter>
nnoremap <silent> <Leader>v :NERDTreeFind<CR>

autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
" Start NERDTree. If a file is specified, move the cursor to its window.
autocmd StdinReadPre * let s:std_in=1
"autocmd VimEnter * NERDTree | if argc() > 0 || exists("s:std_in") | wincmd p | endif  