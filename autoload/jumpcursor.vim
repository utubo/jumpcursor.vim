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

function! s:popup_marks(what, wl, wc) abort
  let savepos = getpos('.')
  normal! 0
  let line_d = 0
  while line('.') !=# a:wl || col('.') != 1
    if line('.') < a:wl
      normal! gj
      let line_d += 1
    else
      normal! gk
      let line_d -= 1
    endif
  endwhile
  let save_ve = &virtualedit
  set virtualedit=block
  execute "normal! \<C-v>g$"
  let width = virtcol('.')
  if ! &wrap
    let width -= 1
  endif
  execute "normal! \<ESC>"
  let &virtualedit = save_ve
  call setpos('.', savepos)
  let id = popup_create(a:what, {
        \ 'line': printf('cursor%+d', line_d),
        \ 'col': printf('cursor%+d', a:wc - virtcol('.')),
        \ 'wrap': &wrap,
        \ 'minwidth': width,
        \ 'maxwidth': width,
        \ 'maxheight': winheight('.'),
        \ 'highlight': 'Error',
        \ })
  call win_execute(id, 'setl tabstop=' . &tabstop)
  call win_execute(id, 'setl ' . (&breakindent ? '' : 'no') . 'breakindent')
  return id
endfunction

function! s:fill_window() abort
  let start_line = line('w0')
  let end_line = line('w$')
  let bufnr = bufnr()
  let mark_len = len(g:jumpcursor_marks)

  " [[1, 1], [1,2], [1,5]]
  let linecols = []
  let mark_idx = 0

  if ! has('nvim')
    let marked_text = []
  endif

  while start_line <= end_line
    if mark_idx >= mark_len
      break
    endif
    if foldclosed(start_line) !=# -1
      if ! has('nvim')
        call add(marked_text, foldtextresult(start_line))
      endif
      let start_line = foldclosedend(start_line) + 1
      continue
    endif
    let text = getline(start_line)
    let mark = g:jumpcursor_marks[mark_idx]
    if has('nvim')
      for i in range(len(text))
        " skip blank
        if text[i] ==# ' ' || text[i] ==# "\t"
          continue
        endif
        call nvim_buf_set_extmark(bufnr, s:jumpcursor_ns, start_line-1, i, {
              \ 'virt_text_pos': 'overlay',
              \ 'virt_text':
              \ [
                \ [mark, 'ErrorMsg']
              \ ]})
        call add(linecols, [start_line-1, i])
      endfor
    else
      call add(marked_text, substitute(text, '\(\S\)', { m -> repeat(mark, strdisplaywidth(m[1])) }, 'g'))
    endif
    let s:jumpcursor_mark_lnums[mark] = start_line
    let mark_idx += 1
    let start_line += 1
  endwhile
  if ! has('nvim')
    let s:popupwin_fill = s:popup_marks(marked_text, line('w0'), 1)
  endif
endfunction

function! s:fill_specific_line(lnum) abort
  let text = getline(a:lnum)
  let bufnr = bufnr()
  let mark_idx = 0
  let mark_len = len(g:jumpcursor_marks)

  if ! has('nvim')
    let marked_text = ''
  endif

  let i = 0
  for c in split(text, '\zs')
    if mark_idx >= mark_len
      break
    endif

    if c ==# ' ' || c ==# "\t"
      if ! has('nvim')
        let marked_text .= c
      endif
      let i += len(c)
      continue
    endif

    let mark = g:jumpcursor_marks[mark_idx]
    let mark_dsp = repeat(mark, strdisplaywidth(c))
    let mark_idx += 1

    if has('nvim')
      call nvim_buf_set_extmark(bufnr, s:jumpcursor_ns, a:lnum-1, i, {
            \ 'virt_text_pos': 'overlay',
            \ 'virt_text':
            \ [
              \ [mark_dsp, 'ErrorMsg']
            \ ]})
    else
      let marked_text .= mark_dsp
    endif

    let s:jumpcursor_mark_cols[mark] = i
    let i += len(c)
  endfor
  if ! has('nvim')
    let s:popupwin_line = s:popup_marks(marked_text, a:lnum, 1)
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
