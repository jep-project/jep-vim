" create buffer and window
sv jep-debug
let g:jep_debug_buffer = bufnr("%")
" close window
close
 
function! s:min_length(ary1, ary2)
  return len(a:ary1) < len(a:ary2) ? len(a:ary1) : len(a:ary2)
endfunction

" offset of first different line 
" runs from the first element forward or the last element backward (reverse == true)
" equal to length of shorter file if no different line is found
function! s:first_diff_offset(lines1, lines2, reverse)
  let minlen = s:min_length(a:lines1, a:lines2)
  let si = 0
  let ei = minlen-1
  while ei > si
    let len = ei - si + 1
    let m = si + float2nr(floor(len/2)) - 1
    if !a:reverse
      let equal = (a:lines1[si : m] == a:lines2[si : m])
    else
      let equal = (a:lines1[-1-m : -1-si] == a:lines2[-1-m : -1-si])
    end
    if equal
      let si = m+1
    else
      let ei = m
    endif
  endwhile
  " si == ei
  if !a:reverse
    let equal = a:lines1[si] == a:lines2[si]
  else
    let equal = a:lines1[-1-si] == a:lines2[-1-si]
  end
  if equal
    return si+1
  else 
    return si
  endif
endfunction

function! s:make_diff(lines1, lines2)
  let minlen = s:min_length(a:lines1, a:lines2)
  let start_offset = s:first_diff_offset(a:lines1, a:lines2, 0)
  if start_offset == minlen
    " not found
    if len(a:lines1) > len(a:lines2)
      " cut lines1 at the end
      return [len(a:lines2), len(a:lines1), len(a:lines2), len(a:lines2)]
    elseif len(a:lines1) < len(a:lines2)
      " added to lines1 at the end
      return [len(a:lines1), len(a:lines1), len(a:lines1), len(a:lines2)]
    else
      " no change
      return []
    endif
  else
    let end_offset = s:first_diff_offset(a:lines1, a:lines2, 1)
    if len(a:lines1) < len(a:lines2)
      if start_offset > len(a:lines1)-end_offset
        let end_offset = len(a:lines1)-start_offset
      endif
    else
      if start_offset > len(a:lines2)-end_offset
        let end_offset = len(a:lines2)-start_offset
      end
    end
    return [start_offset, len(a:lines1)-end_offset, start_offset, len(a:lines2)-end_offset]
  endif
endfunction

function! s:debug_print(msg)
  let winbefore = winnr()
  let debugwin = bufwinnr(g:jep_debug_buffer)
  if debugwin > -1
    execute debugwin . "wincmd w"
    let failed = append(line("$"), a:msg) 
    execute winbefore . "wincmd w"
  endif
endfunction

function! s:ping()
  if exists("b:last_changedtick") && b:changedtick > b:last_changedtick && bufnr("%") != g:jep_debug_buffer
    let lines = getline(0, "$") 
    if exists("b:last_lines")
      let change = s:make_diff(b:last_lines, lines)
    else
      let change = []
    endif
    call s:debug_print("changed win ".winnr()." [".len(lines)." lines] ".join(change, ",")) 
    if len(change) > 0
      if change[3] > change[2]
        if change[1] > change[0]
          if change[1] == change[0]+1
            call s:debug_print("--- changed line ".(change[0]+1))
          else
            call s:debug_print("--- changed lines ".(change[0]+1)." to ".change[1])
          endif
          call s:debug_print(join(b:last_lines[change[0] : change[1]-1], "\\n"))
          call s:debug_print("--- into:")
          call s:debug_print(join(lines[change[2] : change[3]-1], "\\n"))
        else
          call s:debug_print("--- inserted at line ".(change[0]+1))
          call s:debug_print(join(lines[change[2] : change[3]-1], "\\n"))
        endif
      else
        if change[1] == change[0]+1
          call s:debug_print("--- deleted line ".(change[0]+1))
        else
          call s:debug_print("--- deleted lines ".(change[0]+1)." to ".change[1])
        endif
        call s:debug_print(join(b:last_lines[change[0] : change[1]-1], "\\n"))
      endif
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

