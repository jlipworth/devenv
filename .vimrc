" =============================================================================
" Modern .vimrc - 2025 Edition
" =============================================================================
" Gracefully works across: Vim 8+, Neovim, VSCode, minimal vim modes
" Plugin manager: vim-plug (auto-installs if missing)
" =============================================================================

set nocompatible
filetype off

" =============================================================================
" ENVIRONMENT DETECTION
" =============================================================================

" Detect Neovim
let g:is_nvim = has('nvim')

" Detect Vim version
let g:is_vim8 = v:version >= 800
let g:is_vim9 = v:version >= 900

" Detect VSCode
let g:is_vscode = exists('g:vscode')

" Detect GUI vs Terminal
let g:is_gui = has('gui_running')
let g:is_terminal = !has('gui_running')

" Detect OS
let g:is_win = has('win32') || has('win64') || has('win32unix')
let g:is_mac = has('mac') || has('macunix') || has('gui_macvim')
let g:is_linux = has('unix') && !has('macunix') && !has('win32unix')

" Detect minimal vim mode (IdeaVim, VSCode, etc.)
let g:is_minimal = exists('g:loaded_ideavim') || g:is_vscode

" Feature detection
let g:has_terminal = exists(':terminal') == 2
let g:has_async = has('job') || has('nvim')

" =============================================================================
" VSCODE EARLY EXIT
" =============================================================================
" VSCode has its own plugin ecosystem - just provide basic vim settings

if g:is_vscode
  set clipboard=unnamedplus
  set ignorecase
  set smartcase
  set hlsearch
  set incsearch
  set number
  set expandtab
  set tabstop=4
  set shiftwidth=4

  " Basic remaps VSCode respects
  nnoremap j gj
  nnoremap k gk
  inoremap jk <Esc>

  " VSCode command integration
  nnoremap <leader>ff <Cmd>call VSCodeNotify('workbench.action.quickOpen')<CR>
  nnoremap <leader>fg <Cmd>call VSCodeNotify('workbench.action.findInFiles')<CR>
  nnoremap <leader>ne <Cmd>call VSCodeNotify('workbench.view.explorer')<CR>

  finish  " Exit early - don't load plugins
endif

" =============================================================================
" PLUGIN MANAGER: vim-plug (auto-install)
" =============================================================================

" Determine plug directory based on OS
if g:is_win
  let s:plug_dir = expand('~/vimfiles/plugged')
  let s:plug_file = expand('~/vimfiles/autoload/plug.vim')
else
  let s:plug_dir = expand('~/.vim/plugged')
  let s:plug_file = expand('~/.vim/autoload/plug.vim')
endif

" Auto-install vim-plug if missing
if empty(glob(s:plug_file))
  if executable('curl')
    silent execute '!curl -fLo ' . s:plug_file . ' --create-dirs
          \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
  else
    echomsg "vim-plug not installed and curl not available. Plugins disabled."
    let g:plugins_disabled = 1
  endif
endif

" Helper function to check if plugin is loaded
function! s:PlugLoaded(name)
  return isdirectory(s:plug_dir . '/' . a:name)
endfunction

" =============================================================================
" PLUGINS
" =============================================================================

if !exists('g:plugins_disabled')
  call plug#begin(s:plug_dir)

  " --- Core Functionality ---
  Plug 'preservim/nerdtree'              " File explorer
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }  " Fuzzy finder
  Plug 'junegunn/fzf.vim'                " FZF vim integration
  Plug 'dense-analysis/ale'              " Async linting (replaces Syntastic)
  Plug 'tpope/vim-fugitive'              " Git integration
  Plug 'airblade/vim-gitgutter'          " Git diff in gutter

  " --- Editing Enhancements ---
  Plug 'tpope/vim-surround'              " Surround text objects
  Plug 'tpope/vim-commentary'            " Comment stuff out (gcc)
  Plug 'jiangmiao/auto-pairs'            " Auto-close brackets
  Plug 'junegunn/vim-easy-align'         " Alignment

  " --- UI/Appearance ---
  Plug 'vim-airline/vim-airline'         " Status line
  Plug 'vim-airline/vim-airline-themes'  " Airline themes
  Plug 'tomasr/molokai'                  " Color scheme

  " --- Language Support ---
  Plug 'sheerun/vim-polyglot'            " Language pack (syntax for 100+ languages)
  Plug 'lervag/vimtex'                   " Modern LaTeX (replaces LaTeX-Suite)

  " --- Optional/Situational ---
  Plug 'tpope/vim-speeddating'           " Increment dates with C-A/C-X
  Plug 'rhysd/vim-grammarous'            " Grammar checking

  call plug#end()
endif

filetype plugin indent on

" =============================================================================
" BASIC OPTIONS
" =============================================================================

set number                    " Line numbers
set expandtab                 " Spaces instead of tabs
set tabstop=4                 " Tab = 4 spaces
set shiftwidth=4              " Indent = 4 spaces
set autoindent                " Copy indent from current line
set breakindent               " Wrapped lines preserve indent
set linebreak                 " Wrap at word boundaries
set textwidth=100             " Wrap at 100 chars
set backspace=indent,eol,start

" Search
set hlsearch                  " Highlight search results
set incsearch                 " Incremental search
set ignorecase                " Case insensitive...
set smartcase                 " ...unless uppercase used

" UI
set laststatus=2              " Always show statusline
set fillchars+=vert:\│        " Nicer vertical split char
set encoding=utf-8
set timeoutlen=200            " Match Spacemacs evil-escape-delay

" Remove GUI clutter (if applicable)
set guioptions-=m             " No menu
set guioptions-=T             " No toolbar
set guioptions-=r             " No right scrollbar
set guioptions-=L             " No left scrollbar

" Syntax and colors
syntax enable
if filereadable(expand(s:plug_dir . '/molokai/colors/molokai.vim'))
  colorscheme molokai
endif

" Font (GUI)
if g:is_gui
  if g:is_mac
    set guifont=MesloLGMDZ\ Nerd\ Font\ Mono:h12
  elseif g:is_win
    set guifont=MesloLGMDZ_Nerd_Font_Mono:h10
  else
    set guifont=MesloLGMDZ\ Nerd\ Font\ Mono\ 10
  endif
endif

" Folding
set foldmarker=~~,c~~

" =============================================================================
" KEYMAPS
" =============================================================================

" Escape from insert mode
inoremap jk <Esc>

" Visual line navigation
nnoremap j gj
nnoremap k gk

" Command-line navigation
cnoremap <C-h> <Left>
cnoremap <C-l> <Right>
cnoremap <C-j> <Down>
cnoremap <C-k> <Up>
cnoremap <C-^> <Home>
cnoremap <C-$> <End>

" Replace char with space
nnoremap ;m i <Esc>r

" Insert date (global - matches old .vimrc)
nnoremap <leader>dat "=strftime("%b %d, %Y")<CR>p

" Insert date (Spacemacs style: localleader o c)
let maplocalleader = ","

" =============================================================================
" PLUGIN CONFIGURATIONS
" =============================================================================

" --- NERDTree ---
if s:PlugLoaded('nerdtree')
  nnoremap <leader>ne :NERDTreeToggle<CR>
  nnoremap <leader>nf :NERDTreeFind<CR>
  let NERDTreeShowHidden = 1
  let NERDTreeIgnore = ['\.pyc$', '__pycache__', '\.git$']
endif

" --- FZF (replaces CtrlP) ---
if s:PlugLoaded('fzf.vim')
  nnoremap <C-p> :Files<CR>
  nnoremap <leader>ff :Files<CR>
  nnoremap <leader>fg :Rg<CR>
  nnoremap <leader>fb :Buffers<CR>
  nnoremap <leader>fh :History<CR>
  nnoremap <leader>fm :Marks<CR>

  " Use ripgrep if available
  if executable('rg')
    let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --glob "!.git/*"'
  endif
endif

" --- ALE (replaces Syntastic) ---
if s:PlugLoaded('ale')
  let g:ale_linters = {
        \ 'python': ['flake8', 'pylint', 'ruff'],
        \ 'sql': ['sqlint'],
        \ 'tex': ['chktex'],
        \ 'sh': ['shellcheck'],
        \ 'javascript': ['eslint'],
        \ 'typescript': ['eslint', 'tsserver'],
        \ }
  let g:ale_fixers = {
        \ '*': ['remove_trailing_lines', 'trim_whitespace'],
        \ 'python': ['black', 'isort'],
        \ 'javascript': ['prettier'],
        \ 'typescript': ['prettier'],
        \ }
  let g:ale_lint_on_text_changed = 'normal'
  let g:ale_lint_on_save = 1
  let g:ale_fix_on_save = 0  " Set to 1 if you want auto-fix

  " Navigate between errors
  nmap <silent> [e <Plug>(ale_previous_wrap)
  nmap <silent> ]e <Plug>(ale_next_wrap)
endif

" --- Airline ---
if s:PlugLoaded('vim-airline')
  let g:airline_theme = 'powerlineish'
  let g:airline#extensions#tabline#enabled = 1
  let g:airline_powerline_fonts = 1

  " Integration with ALE
  if s:PlugLoaded('ale')
    let g:airline#extensions#ale#enabled = 1
  endif
else
  " Fallback statusline if airline not available
  set statusline=%f\ %m%r%h%w\ [%{&ff}]\ %y\ [%l/%L\ %c]\ %P
endif

" --- VimTeX (modern LaTeX - replaces LaTeX-Suite) ---
if s:PlugLoaded('vimtex')
  let g:tex_flavor = 'latex'
  let g:vimtex_view_method = 'skim'  " macOS
  if g:is_linux
    let g:vimtex_view_method = 'zathura'
  elseif g:is_win
    let g:vimtex_view_method = 'sumatrapdf'
  endif
  let g:vimtex_compiler_method = 'latexmk'
  let g:vimtex_quickfix_mode = 0  " Don't auto-open quickfix
endif

" --- vim-easy-align ---
if s:PlugLoaded('vim-easy-align')
  xmap ga <Plug>(EasyAlign)
  nmap ga <Plug>(EasyAlign)
endif

" --- Git Gutter ---
if s:PlugLoaded('vim-gitgutter')
  set updatetime=100  " Faster git gutter updates
endif

" =============================================================================
" FILETYPE-SPECIFIC SETTINGS
" =============================================================================

augroup filetypes
  autocmd!

  " --- TeX/LaTeX ---
  autocmd FileType tex setlocal spell
  autocmd FileType tex setlocal formatoptions-=t
  autocmd FileType tex nnoremap <buffer> j gj
  autocmd FileType tex nnoremap <buffer> k gk
  autocmd FileType tex nnoremap <buffer> $ g$
  autocmd FileType tex nnoremap <buffer> 0 g0
  autocmd FileType tex nnoremap <buffer> ^ g^
  autocmd FileType tex let b:AutoPairs = {'(':')', '[':']', '{':'}', '``':'"'}
  autocmd FileType tex nnoremap <buffer> <localleader>oc :put =strftime('%b %d, %Y')<CR>

  " --- Org ---
  autocmd FileType org nnoremap <buffer> <localleader>oc :put =strftime('%b %d, %Y')<CR>

  " --- Text ---
  autocmd FileType text setlocal formatoptions-=t
  autocmd FileType text setlocal spell

  " --- Vim ---
  autocmd FileType vim setlocal foldmethod=marker

  " --- Python ---
  autocmd FileType python setlocal tabstop=4 shiftwidth=4

  " --- JavaScript/TypeScript ---
  autocmd FileType javascript,typescript,json setlocal tabstop=2 shiftwidth=2

  " --- YAML ---
  autocmd FileType yaml setlocal tabstop=2 shiftwidth=2

augroup END

" =============================================================================
" NEOVIM-SPECIFIC
" =============================================================================

if g:is_nvim
  " True color support
  if has('termguicolors')
    set termguicolors
  endif

  " Use system clipboard
  set clipboard+=unnamedplus
endif

" =============================================================================
" LOCAL OVERRIDES
" =============================================================================
" Source local config if exists (for machine-specific settings)

if filereadable(expand('~/.vimrc.local'))
  source ~/.vimrc.local
endif
