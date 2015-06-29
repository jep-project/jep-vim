function! g:jep_make_diff(lines1, lines2)
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

function! s:min_length(ary1, ary2)
  return len(a:ary1) < len(a:ary2) ? len(a:ary1) : len(a:ary2)
endfunction

