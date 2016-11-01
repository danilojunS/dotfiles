set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

Plugin 'flazz/vim-colorschemes'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'scrooloose/nerdtree'
Plugin 'scrooloose/nerdcommenter'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'scrooloose/syntastic'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-surround'
Plugin 'tpope/vim-commentary'
Plugin 'christoomey/vim-sort-motion'
Plugin 'christoomey/vim-system-copy'
Plugin 'Valloric/YouCompleteMe'
Plugin 'easymotion/vim-easymotion'
Plugin 'junegunn/vim-easy-align'
Plugin 'mhinz/vim-signify'
Plugin 'Raimondi/delimitMate'
Plugin 'pangloss/vim-javascript'
Plugin 'jelera/vim-javascript-syntax'
Plugin 'ternjs/tern_for_vim'
Plugin 'helino/vim-json'
Plugin 'christoomey/vim-tmux-navigator'
Plugin 'Chiel92/vim-autoformat'
Plugin 'majutsushi/tagbar'
Plugin 'mileszs/ack.vim'
Plugin 'JamshedVesuna/vim-markdown-preview'
Plugin 'terryma/vim-smooth-scroll'
Plugin 'mhinz/vim-startify'
Plugin 'craigemery/vim-autotag'
Plugin 'Xuyuanp/nerdtree-git-plugin'
Plugin 'ryanoasis/vim-devicons'
Plugin 'tiagofumo/vim-nerdtree-syntax-highlight'
Plugin 'romgrk/winteract.vim'
Plugin 'nikvdp/ejs-syntax'
Plugin 'othree/html5.vim'
Plugin 'valloric/matchtagalways'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ

"" PLUGINS CONFIGURATION

" NERDTree
map <Leader>t :NERDTreeToggle<CR>
let NERDTreeShowHidden=1
let NERDTreeIgnore = ['\.swp$']

" vim-devicons
let g:WebDevIconsUnicodeDecorateFolderNodes = 1
let g:DevIconsEnableFolderExtensionPatternMatching = 1

" vim-nerdtree-syntax-highlight
let g:NERDTreeHighlightFolders = 1 " enables folder icon highlighting using exact match
let g:NERDTreeHighlightFoldersFullName = 1 " highlights the folder name

" tagbar
nmap <Leader>b :TagbarToggle<CR>

" vim-autotag
let g:autotagTagsFile=".tags"

" tern_for_vim

" auxiliary functions

function GoToDefinition()
  if (&ft=='javascript')
    :TernDef
  else
    :echom 'GoToDefinition() not implemented for this filetype'
  endif
endfunction

function ShowReferences()
  if (&ft=='javascript')
    :TernRefs
  else
    :echom 'ShowReferences() not implemented for this filetype'
  endif
endfunction

function ShowDocs()
  if (&ft=='javascript')
    :TernDoc
  else
    :echom 'ShowDocs() not implemented for this filetype'
  endif
endfunction

if has('macunix')
  " go to definition: alt + j = ∆ (mac)
  noremap ∆ :call GoToDefinition()<CR>
  " go back: alt + k = ˚ (mac)
  noremap ˚ <c-o>
  " show docs: alt + h = ˙ (mac)
  noremap ˙ :call ShowDocs()<CR>
  " show references: alt + l = ¬ (mac)
  noremap ¬ :call ShowReferences()<CR>
endif

" The Silver Searcher
if executable('ag')
  " User ag over ack
  let g:ackprg = 'ag --hidden --vimgrep --silent --path-to-agignore ~/.agignore'

  " Use ag over grep
  set grepprg=ag\ --nogroup\ --nocolor\ --silent\ --path-to-agignore\ ~/.agignore

  " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
  let g:ctrlp_user_command = 'ag --hidden %s -l --nocolor --silent -g "" --path-to-agignore ~/.agignore'

  " ag is fast enough that CtrlP doesn't need to cache
  let g:ctrlp_use_caching = 0
endif

" bind \ (backward slash) to grep shortcut
command -nargs=+ -complete=file -bar Ag silent! grep! <args>|cwindow|redraw!
nnoremap \ :Ag<SPACE>

" ack.vim
" nnoremap <Leader>a :Ack!<Space>

" ctrlp
let g:ctrlp_show_hidden=1
set wildignore+=*/tmp/*,*.so,*.swp,*.zip
" let g:ctrlp_custom_ignore = {
"       \ 'dir':  '\v[\/]\.(git|hg|svn)$',
"       \ 'file': '\v\.(exe|so|dll)$'
"       \ }

" EasyAlign
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)
" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" vim-autoformat
nmap <Leader>f :Autoformat<CR>

" vim-javacript
let g:javascript_plugin_jsdoc = 1
"
" let g:javascript_conceal_function       = "ƒ"
" let g:javascript_conceal_null           = "ø"
" let g:javascript_conceal_this           = "@"
" let g:javascript_conceal_return         = "⇚"
" let g:javascript_conceal_undefined      = "¿"
" let g:javascript_conceal_NaN            = "ℕ"
" let g:javascript_conceal_prototype      = "¶"
" let g:javascript_conceal_static         = "•"
" let g:javascript_conceal_super          = "Ω"
" let g:javascript_conceal_arrow_function = "⇒"

set conceallevel=1
set concealcursor=nvic

" vim-startify
let g:startify_change_to_dir = 0
let g:startify_change_to_vcs_root = 1

" airline
set laststatus=2
let g:airline_powerline_fonts = 1
let g:airline_theme='ubaryd'

" syntastic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 0
let g:syntastic_check_on_wq = 1

let g:syntastic_javascript_checkers = ['eslint']

" matchtagalways
nnoremap <leader>% :MtaJumpToOtherTag<cr>
let g:mta_use_matchparen_group = 1
let g:mta_filetypes = {
      \ 'html' : 1,
      \ 'xhtml' : 1,
      \ 'xml' : 1,
      \ 'ejs' : 1,
      \}

" markdown-preview
let vim_markdown_preview_hotkey='<C-m>'
let vim_markdown_preview_github=1           " requires installation of grip

" vim-smooth-scroll
" parameters: distance, duration, speed
noremap <silent> <c-u> :call smooth_scroll#up(&scroll, 0, 4)<CR>
noremap <silent> <c-d> :call smooth_scroll#down(&scroll, 0, 4)<CR>
noremap <silent> <c-b> :call smooth_scroll#up(&scroll*2, 0, 8)<CR>
noremap <silent> <c-f> :call smooth_scroll#down(&scroll*2, 0, 8)<CR>

" winteract
nmap <leader>w :InteractiveWindow<CR>

" colorschemes
set t_Co=256
colorscheme hybrid_material
