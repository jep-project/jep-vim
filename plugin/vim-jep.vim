set updatetime=1000
 
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

function! s:ping()
  if exists("b:last_changedtick") && b:changedtick > b:last_changedtick
    let lines = getline(0, "$") 
    if exists("b:last_lines")
      let change = s:make_diff(b:last_lines, lines)
    else
      let change = []
    endif
    let debug_console = "jep-debug"
    call g:console_write(debug_console, "changed win ".winnr()." [".len(lines)." lines] ".join(change, ",")) 
    if len(change) > 0
      if change[3] > change[2]
        if change[1] > change[0]
          if change[1] == change[0]+1
            call g:console_write(debug_console, "--- changed line ".(change[0]+1)." [".line2byte(change[0]+1).",".line2byte(change[0]+2)."]")
          else
            call g:console_write(debug_console, "--- changed lines ".(change[0]+1)." to ".change[1]." [".line2byte(change[0]+1).",".line2byte(change[1]+1)."]")
          endif
          call g:console_write(debug_console, join(b:last_lines[change[0] : change[1]-1], "\\n"))
          call g:console_write(debug_console, "--- into:")
          call g:console_write(debug_console, join(lines[change[2] : change[3]-1], "\\n"))
        else
          call g:console_write(debug_console, "--- inserted at line ".(change[0]+1)." [".line2byte(change[0]+1)."]")
          call g:console_write(debug_console, join(lines[change[2] : change[3]-1], "\\n"))
        endif
      else
        if change[1] == change[0]+1
          call g:console_write(debug_console, "--- deleted line ".(change[0]+1)." [".line2byte(change[0]+1).",".line2byte(change[0]+2)."]")
        else
          call g:console_write(debug_console, "--- deleted lines ".(change[0]+1)." to ".change[1]." [".line2byte(change[0]+1).",".line2byte(change[1]+1)."]")
        endif
        call g:console_write(debug_console, join(b:last_lines[change[0] : change[1]-1], "\\n"))
      endif
    endif

ruby << RUBYEOF
    sync_backend
RUBYEOF

    let b:last_lines = lines
  endif
  let b:last_changedtick = b:changedtick

ruby << RUBYEOF
  $connector_manager.all_connectors.each do |c|
    c.work
    c.read_service_output_lines.each do |l|
      VIM::command("call g:console_write(\"jep-debug\", #{l.inspect})")
    end
  end
RUBYEOF

  " retrigger hold event
  if mode() == "i"
    " escape and re-enter insert mode
    call feedkeys("\ea")
  else
    " start search and cancel
    call feedkeys("f\e")
  endif
endfunction

function! s:leave()
ruby << RUBYEOF
  VIM.message("leaving...")
  $connector_manager.all_connectors.each do |c|
    c.stop
  end
  VIM.message("exit now")
  sleep(1)
RUBYEOF
endfunction

function! s:bufRead()
ruby << RUBYEOF
  sync_backend
RUBYEOF
endfunction

augroup jep 
  au!
  " au CursorMoved * call s:ping()
  " au CursorMovedI * call s:ping()
  " au InsertLeave * call s:ping()
  au CursorHold * call s:ping()
  au CursorHoldI * call s:ping()
  au VimLeave * call s:leave()
  au BufRead * call s:bufRead()
augroup end

ruby << RUBYEOF
$:.unshift("c:/users/mthiede/gitrepos/ruby-jep/lib")
$:.unshift("c:/users/mthiede/gitrepos/win32-process/lib")
require 'logger'
require 'jep/frontend/connector_manager'
require 'jep/frontend/default_handler'

def sync_backend
  file = VIM::evaluate('expand("%:p")')
  connector = $connector_manager.connector_for_file(file)
  if connector
    unless connector.connected?
      connector.start 
      connector.work :for => 5, :while => ->{ !connector.connected? }
    end
    lines = VIM::evaluate('getline(0, "$")')
    connector.message_handler.sync_file(file, lines.join("\n"))
  else
    VIM.message("JEP: no config for #{file}")
  end
end

class ConnectorLogger
  def initialize(jep_file)
    @jep_file = jep_file
  end
  def debug(msg)
    log("DEBUG: #{msg}")
  end
  def info(msg)
    log("INFO: #{msg}")
  end
  def warn(msg)
    log("WARN: #{msg}")
  end
  def error(msg)
    log("ERROR: #{msg}")
  end
  def fatal(msg)
    log("FATAL: #{msg}")
  end
  def log(msg)
    console_name = "JEP: #{@jep_file}"
    VIM::evaluate("g:console_write(\"#{console_name}\",#{msg.inspect})")
  end
end

def create_handler
  JEP::Frontend::DefaultHandler.new(
    :on_problem_change => ->(probs) do 
      VIM::evaluate("g:console_write(\"jep-debug\",\"problem update\")")
      wd = VIM::evaluate("getcwd()").gsub("\\", "/")
      problems = []
      probs.each do |p|
        file = p.file.gsub("\\", "/").sub(wd, "").sub(/^\//, "")
        problems << "#{file}:#{p.line}:#{p.message}"
      end
      VIM::command("cexpr [#{problems.collect{|p| p.inspect}.join(",")}]")
    end
  )
end

$connector_manager = JEP::Frontend::ConnectorManager.new do |config|
  logger = ConnectorLogger.new(config.file)
  handler = create_handler
  con = JEP::Frontend::Connector.new(config, 
    :logger => logger,
    :log_service_output => true,
    :message_handler => handler)
  handler.connector = con
  con
end

RUBYEOF

"silent execute 'match SpellBad /\%'.linenum.'l\V\^'.escape(getline(linenum), '\').'\$/'
