" create buffer and window
sv jep-debug
let g:jep_debug_buffer = bufnr("%")
" close window
close

function! s:make_diff(lines, last_lines)
  let b1 = 0
  let b2 = len(a:lines) < len(a:last_lines) ? len(a:lines) : len(a:last_lines)
  while b2 > b1 + 1 
    let m = b1 + ((b2 - b1)/2)
    if a:lines[b1 : m] == a:last_lines[b1 : m]
      let b1 = m
    else
      let b2 = m
    endif
  endwhile

  return [ m ]
  let i=0
  let first_changed = -1
  while i < len(a:lines) && i < len(a:last_lines)
    if a:lines[i] != a:last_lines[i]
      let first_changed = i
    endif
    let i += 1
  endwhile
  let last_changed = -1
  " let i=1 " while i <= len(a:lines) && i <= len(a:last_lines)
  "   if a:lines[-i] != a:last_lines[-i]
  "     let last_changed = i
  "   endif
  "   let i += 1
  " endwhile
  return [ first_changed, len(a:lines)-last_changed ]
endfunction

function! s:ping()
  let winbefore = winnr()
  let debugwin = bufwinnr(g:jep_debug_buffer)
  if exists("b:last_changedtick") && b:changedtick > b:last_changedtick && bufnr("%") != g:jep_debug_buffer
    let lines = getline(0, "$") 
    if exists("b:last_lines")
      let change = s:make_diff(lines, b:last_lines)
    else
      let change = []
    endif
    if debugwin > -1
      execute debugwin . "wincmd w"
      let failed = append(line("$"), "changed ".winbefore." ".len(lines)." ".join(change, ",")) 
      execute winbefore . "wincmd w"
    endif
    let b:last_lines = lines
  endif
  let b:last_changedtick = b:changedtick
endfunction

augroup jep 
  au!
  " au CursorMoved * call s:ping()
  " au CursorMovedI * call s:ping()
  " au InsertLeave * call s:ping()
  au CursorHold * call s:ping()
  au CursorHoldI * call s:ping()
augroup end

