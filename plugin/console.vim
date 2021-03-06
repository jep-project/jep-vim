" write +msg+ to a new console window titled +console+
" if the third argument is true, the console window will be shown in a new window
function! g:console_write(console, msg, ...)
  call s:console_write(a:console, a:msg, a:0)
endfunction

augroup jep_console
  au!
  au InsertLeave * call s:insert_mode_leave()
augroup end

let s:console_descs = {}

function! s:console_write(console, msg, show)
  " remember active window
  let cdesc = get(s:console_descs, a:console)
  if type(cdesc) == type({})
    let bufnr = cdesc.bufnr
    let winnr = bufwinnr(bufnr)
    let winbefore = winnr()
    if winnr > -1 && s:can_change_window()
      " console buffer open in window
      " note: we don't change to another window while in insert mode
      " since this would mess up the undo history
      " instead we insert the message when the users leaves insert mode
      execute winnr . "wincmd w"
      call s:write_msg("[".bufnr."] ".a:msg)
    elseif bufexists(bufnr)
      if a:show && s:can_change_window()
        " display buffer in new window
        execute "split #" . bufnr
        call s:write_msg("[".bufnr."] ".a:msg)
        let winbefore = winnr('#')
      else
        " console buffer hidden
        " append to message queue since we can't write to hidden buffer
        let cdesc.messages = add(cdesc.messages, "[".bufnr."] ".a:msg)
      endif
    else
      " buffer has been closed, create new one
      call s:console_write_new(a:console, a:msg, a:show)
      let winbefore = winnr('#')
    endif
  else
    " new console
    call s:console_write_new(a:console, a:msg, a:show)
    let winbefore = winnr('#')
  endif
  " switch back to original window
  execute winbefore . "wincmd w"
endfunction

function! s:can_change_window()
  return mode() != "i" && mode() != "v" && mode() != "V" && mode() != ""
endfunction

function! s:insert_mode_leave()
  for cdesc in values(s:console_descs)
    if type(cdesc) == type({})
      let winnr = bufwinnr(cdesc.bufnr)
      if winnr > -1 && mode() != "i"
        " console buffer open in window
        let winbefore = winnr()
        execute winnr . "wincmd w"
        call s:buffer_shown()
        " switch back to original window
        execute winbefore . "wincmd w"
      endif
    endif
  endfor
endfunction

function! s:console_write_new(console, msg, show)
  " create new console descriptor
  let cdesc = {}
  let s:console_descs[a:console] = cdesc
  let cdesc.messages = []
  " create new buffer
  let cdesc.bufnr = bufnr(a:console, 1)
  " open new buffer in new window
  execute "sbuffer " . cdesc.bufnr
  " bufnr created an unlisted buffer, set to listed
  set buflisted
  set noreadonly
  " with 'nofile', the buffer can't be written and doesn't become dirty
  set buftype=nofile
  " buffer local auto command
  execute "au BufWinEnter <buffer=" . cdesc.bufnr . "> call s:buffer_shown()"
  if a:show
    call s:write_msg(a:msg)
  else
    " close window
    close
    let cdesc.messages = add(cdesc.messages, a:msg)
  endif
endfunction

function! s:write_msg(msg)
  let newlines = split(a:msg, '\r\?\n')
  let emptybefore = (line("$") == 1 && getline(1) == "")
  call append(line("$"), newlines) 
  " go to last line
  if emptybefore
    " if buffer was empty, the first line will be empty after append
    execute "1,1delete"
  endif
  execute line('$')
  redraw
endfunction

" lookup descriptor by buffer number
" note that direct lookup by buffername as key is not reliable since
" VIM's buffer names may differ from the original console names
" (e.g. / is converted to \ on windows)
function! s:find_desc(bufnr)
  for cons in keys(s:console_descs)
    let cdesc = s:console_descs[cons]
    if type(cdesc) == type({}) && cdesc.bufnr == a:bufnr
      return cdesc
    end
  endfor
  return 0
endfunction

function! s:buffer_shown()
  let cdesc = s:find_desc(bufnr('%'))
  if type(cdesc) == type({}) && len(cdesc.messages) > 0
    for msg in cdesc.messages
      call s:write_msg(msg)
    endfor
    call remove(cdesc.messages, 0, -1)
  endif
endfunction

