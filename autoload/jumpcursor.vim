" jumpcursor.vim
" Author: skanehira
" License: MIT

let g:jumpcursor_marks = get(g:, 'jumpcursor_marks', split('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ@[;:],./_-^\1234567890', '\zs'))

let s:jumpcursor_mark_lnums = {}
let s:jumpcursor_mark_cols = {}
if has('nvim')
  let s:jumpcursor_ns = nvim_create_namespace('jumpcursor')
else
  let s:popupwin_fill = 0
  let s:popupwin_line = 0
endif

function! s:fill_window() abort
  let start_line = line('w0')
  let end_line = line('w$')
  let bufnr = bufnr()
  let mark_len = len(g:jumpcursor_marks)

  " [[1, 1], [1,2], [1,5]]
  let linecols = []
  let mark_idx = 0

  if ! has('nvim')
    let mark_text = []
  endif

  while start_line <= end_line
    if mark_idx >= mark_len
      break
    endif
    let text = getline(start_line)
    let mark = g:jumpcursor_marks[mark_idx]
    if ! has('nvim')
      call add(mark_text, '')
    endif
    for i in range(len(text))
      " skip blank
      if text[i] ==# ' ' || text[i] ==# "\t"
        if ! has('nvim')
          let mark_text[-1] .= text[i]
        endif
        continue
      endif
      if has('nvim')
        call nvim_buf_set_extmark(bufnr, s:jumpcursor_ns, start_line-1, i, {
              \ 'virt_text_pos': 'overlay',
              \ 'virt_text':
              \ [
                \ [mark, 'ErrorMsg']
              \ ]})
      else
        let mark_text[-1] .= mark
      endif
      call add(linecols, [start_line-1, i])
    endfor
    let s:jumpcursor_mark_lnums[mark] = start_line
    let mark_idx += 1
    let start_line += 1
  endwhile
  if ! has('nvim')
    let s:popupwin_fill = popup_create(mark_text, {
          \ 'line': 'cursor-' . line('.'),
          \ 'col': 'cursor-' . (col('.') - 1),
          \ 'highlight': 'Error',
          \ })
  endif
endfunction

function! s:fill_specific_line(lnum) abort
  let text = getline(a:lnum)
  let bufnr = bufnr()
  let mark_idx = 0
  let mark_len = len(g:jumpcursor_marks)

  if ! has('nvim')
    let mark_text = ''
  endif

  for i in range(len(text))
    if mark_idx >= mark_len
      break
    endif

    if text[i] ==# ' ' || text[i] ==# "\t"
      if ! has('nvim')
        let mark_text .= text[i]
      endif
      continue
    endif

    let mark = g:jumpcursor_marks[mark_idx]
    let mark_idx += 1

    if has('nvim')
      call nvim_buf_set_extmark(bufnr, s:jumpcursor_ns, a:lnum-1, i, {
            \ 'virt_text_pos': 'overlay',
            \ 'virt_text':
            \ [
              \ [mark, 'ErrorMsg']
            \ ]})
    else
      let mark_text .= mark
    endif

    let s:jumpcursor_mark_cols[mark] = i
  endfor
  if ! has('nvim')
    let s:popupwin_line = popup_create(mark_text, {
          \ 'line': printf('cursor%+d', (a:lnum - line('.'))),
          \ 'col': printf('cursor%+d', 1 - col('.')),
          \ 'highlight': 'Error',
          \ })
  endif
  redraw!
endfunction

function! jumpcursor#jump() abort
  call s:fill_window()
  redraw!

  let mark = getcharstr()
  call s:jump_cursor_clear()

  if mark ==# '' || mark ==# ' ' || !has_key(s:jumpcursor_mark_lnums, mark)
    return
  endif

  let lnum = s:jumpcursor_mark_lnums[mark]

  call s:fill_specific_line(lnum)

  let mark = getcharstr()
  call s:jump_cursor_clear()

  if mark ==# '' || mark ==# ' ' || !has_key(s:jumpcursor_mark_cols, mark)
    return
  endif

  let col = s:jumpcursor_mark_cols[mark] + 1

  call setpos('.', [bufnr(), lnum, col, 0])

  let s:jumpcursor_mark_lnums = {}
  let s:jumpcursor_mark_cols = {}
endfunction

function! s:jump_cursor_clear() abort
  if has('nvim')
    call nvim_buf_clear_namespace(bufnr(), s:jumpcursor_ns, line('w0')-1, line('w$'))
  else
    if s:popupwin_fill
      call popup_close(s:popupwin_fill)
      let s:popupwin_fill = 0
    endif
    if s:popupwin_line
      call popup_close(s:popupwin_line)
      let s:popupwin_line = 0
    endif
  endif
endfunction
