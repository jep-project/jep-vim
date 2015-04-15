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
ruby << RUBYEOF
  #console_write("jep-debug", get_file)
RUBYEOF
  if exists("b:last_changedtick") && b:changedtick > b:last_changedtick
    let lines = getline(0, "$") 
    if exists("b:last_lines")
      let change = s:make_diff(b:last_lines, lines)
    else
      let change = []
    endif
    let debug_console = "jep-debug"
    if len(change) > 0
      call g:console_write(debug_console, "changed win ".winnr()." [".len(lines)." lines] ".join(change, ",")) 
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
ruby << RUBYEOF
      sync_backend
RUBYEOF
    else
      " no change
    endif

    let b:last_lines = lines
  endif
  let b:last_changedtick = b:changedtick

ruby << RUBYEOF
  $connector_manager.all_connectors.each do |c|
    begin
      #console_write("jep-debug", "working...")
      c.work
    rescue Exception => e
      console_write("jep-debug", e.to_s)
      console_write("jep-debug", e.backtrace.join("\n"))
    end
  end
RUBYEOF

  " retrigger hold event
  if mode() == "i"
    "call feedkeys(" \b")
    let c = col(".")
    if c <= len(getline("."))
      call feedkeys("\<Right>")
      call feedkeys("\<Left>")
    else
      call feedkeys("\<Right>")
    endif
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

function! g:jepCompleteFunc(findstart, base) abort
  if a:findstart
    let s:completionOptions = []
ruby << RUBYEOF
    sync_backend
    file = get_file
    con = get_connector(file)
    token = con.message_handler.completion_request(file, cursor_pos)
    result = nil
    begin
      con.work :for => 10, :while => -> do
        result = con.message_handler.completion_result(token)
        result == :pending
      end
    rescue Exception => e
      console_write("jep-debug", e.to_s)
      console_write("jep-debug", e.backtrace.join("\n"))
    end
    start = -1
    case result
    when :invalid
      console_write("jep-debug", "invalid token")
    when :timeout
      console_write("jep-debug", "completion timeout")
    else
      console_write("jep-debug", "completion response")
      # start counts from 0
      start = col_from_pos(result.start)-1
      options = result.options.collect{|o|
        desc = o.desc ? "'menu': '#{o.desc}'," : ""
        info = o.longDesc ? "'info': '#{o.longDesc}'," : ""
        "{'word': '#{o.insert}', #{desc} #{info} 'dup': 1}"
      }.join(",")
      VIM.command("let s:completionOptions = [#{options}]")
    end
    console_write("jep-debug", start)
    VIM.command("let l:result = #{start}")
RUBYEOF
    return l:result
  else
    return s:completionOptions
  endif
endfunction

set omnifunc=g:jepCompleteFunc

augroup jep 
  au!
  " au CursorMoved * call s:ping()
  " au CursorMovedI * call s:ping()
  au CursorHold * call s:ping()
  au CursorHoldI * call s:ping()
  au VimLeave * call s:leave()
  au BufRead * call s:bufRead()
  " switch off visual bell while in insert mode
  " otherwise retriggering of CursorHoldI may cause flickering
  " note that switching of visualbell while in CursorHoldI handler
  " doesn't work, probably because it's too late to take effect
  au InsertEnter * set novisualbell
  " TODO: check if it was on before
  au InsertLeave * set visualbell
augroup end

ruby << RUBYEOF
$:.unshift("c:/users/mthiede/gitrepos/jep-ruby/lib")
$:.unshift("c:/users/mthiede/gitrepos/win32-process/lib")
require 'logger'
require 'rgen/native'
require 'jep/frontend/connector_manager'
require 'jep/frontend/default_handler'

def get_connector(file)
  connector = $connector_manager.connector_for_file(file)
  if connector
    unless connector.connected?
      connector.start 
      connector.work :for => 5, :while => ->{ !connector.connected? }
    end
    if connector.connected?
      connector
    else
      console_write("jep-debug", "connection timeout for #{file}")
      nil
    end
  else
    console_write("jep-debug", "no config for #{file}")
    nil
  end
end

def get_file
  VIM::evaluate('expand("%:p")')
end

def sync_backend
  file = get_file
  con = get_connector(file)
  if con
    lines = VIM::evaluate('getline(0, "$")')
    con.message_handler.sync_file(file, lines.join("\n"))
  end
end

def col_from_pos(pos)
  lines = VIM::evaluate('getline(0, "$")')
  p = 0
  lines.each do |l|
    # +1 for the \n
    line_len = l.size + 1
    if p + line_len > pos
      # col numbers start at 1
      return pos - p + 1
    else
      p += line_len
    end
  end
end

def cursor_pos
  lines = VIM::evaluate('getline(0, ".")')
  pos = 0
  lines[0..-2].each do |l|
    # +1 for the \n
    pos += l.size + 1
  end
  pos += VIM::evaluate('col(".")')-1
  pos
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
    timestamp = Time.now
    console_write("JEP: #{@jep_file}", 
      "#{timestamp.hour}:#{timestamp.min}:#{timestamp.sec}.#{(timestamp.usec/1000).to_s.rjust(3)} #{msg}")
  end
end

def console_write(console_name, msg)
  VIM::evaluate("g:console_write(\"#{console_name}\",#{msg.to_s.inspect})")
end

def create_handler
  JEP::Frontend::DefaultHandler.new(
    :on_problem_change => ->(problems_by_file) do 
      console_write("jep-debug", "problem update")
      wd = VIM::evaluate("getcwd()").gsub("\\", "/")
      problems = []
      problems_by_file.each_pair do |file, probs|
        probs.each do |p|
          file = file.gsub("\\", "/").sub(wd, "").sub(/^\//, "")
          problems << "#{file}:#{p.line}:#{p.message}"
        end
      end
      # user cgetexpr which doesn't jump to first error in the list
      VIM::command("cgetexpr [#{problems.collect{|p| p.inspect}.join(",")}]")
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
