" jumpcursor.vim
" Author: skanehira
" License: MIT

if exists('loaded_jumpcursor')
  finish
endif
let g:loaded_jumpcursor = 1

nnoremap <Plug>(jumpcursor-jump) <Cmd>call jumpcursor#jump()<CR>
