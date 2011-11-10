color tango
syntax on
autocmd FileType python set tabstop=4 shiftwidth=4
autocmd FileType cpp set tabstop=4 shiftwidth=4
set hlsearch
noremap <F4> :set hlsearch! hlsearch?<CR>
"set mouse=ni

"autocmd! InsertLeave * call system("killall -q -USR1 fcitx")
"autocmd! InsertEnter * call system("killall -q -USR2 fcitx") 
"autocmd! VimEnter * call system("killall -q -USR1 fcitx")
"autocmd! VimLeave * call system("killall -q -USR2 fcitx")
