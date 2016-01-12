" load plugins
source ~/.vim/plugins.vim

" color scheme
set t_Co=256
colorscheme xoria256

" syntax highlighting
syntax on

" show hybrid line numbers
set relativenumber
set number

" configure tabs
set expandtab
set smarttab
set shiftwidth=4
set softtabstop=4
set tabstop=4"

" configure special characters
" set listchars=eol:$,tab:>-,trail:~,extends:>,precedes:<
" set list

" mapping keys
let mapleader = ','
map <C-\> :NERDTreeToggle<CR>
:inoremap jk <esc>

" PLUGINS

" airline
set laststatus=2
let g:airline_powerline_fonts = 1
let g:airline_theme='dark'

" syntastic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
