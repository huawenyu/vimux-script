let g:VimuxDebug = 0

" Env Check {{{1
if empty($TMUX)
  echom "Vimux not loaded: not running under Tmux session."
  finish
endif


" Functions {{{1
function! vimux#Prepare()
  if exists("g:VimuxRunnerIndex") && exists("g:VimuxVimIndex")
    return 1
  endif

  if !exists("g:VimuxRunnerIndex") || vimux#_VimuxHasRunner(g:VimuxRunnerIndex) == -1
    call vimux#VimuxOpenRunner()
  endif

  if g:VimuxRunnerIndex < -1
    unlet! g:VimuxRunnerIndex
    echom "No VimxOpenRunner."
    return 0
  endif

  return 1
endfunction

function! vimux#TmuxInfoRefresh()
  if !exists("g:VimuxRunnerIndex")
    echom "TmuxInfoRefresh fail: No VimxOpenRunner."
    return 0
  endif

  let views = split(vimux#_VimuxTmux("list-".vimux#_VimuxRunnerType()
        \."s -F '#{pane_index} #{history_size} #{pane_height} #{cursor_y}'"), "\n")

  for view in views
    let sizes = split(view, ' ')
    if sizes[0] == g:VimuxRunnerIndex
      let g:VimuxRunnerHistorySize = 0 + sizes[1]
      let g:VimuxRunnerPaneHeight = 0 + sizes[2]
      let g:VimuxRunnerCursorY = 0 + sizes[3]
      return 1
    endif
  endfor

  return 0
endfunction

function! vimux#TmuxAttachLists(A, L, P)
  return vimux#_VimuxTmux("list-".vimux#_VimuxRunnerType()."s -F '#{pane_index}'")
endfunction

function! vimux#TmuxAttach(runner)
  if vimux#_VimuxHasRunner(a:runner) == -1
    echom "Vimux attach Runner faild: invalid pane-index " . a:runner
    return 0
  endif

  let g:VimuxRunnerIndex = a:runner
  echom "Vimux attach succ: pane-index " . a:runner
  return 1
endfunction

function! vimux#RunInDir(command, useFile)
    let l:file = ""
    if a:useFile ==# 1
        let l:file = shellescape(expand('%:t'), 1)
    endif
    call vimux#Run("(cd ".shellescape(expand('%:p:h'), 1)." && ".a:command." ".l:file.")")
endfunction

function! vimux#VimuxRunLastCommand()
  if vimux#Prepare()
    call vimux#Run(g:VimuxLastCommand)
  endif
endfunction

function! vimux#Run(command, ...)
  if !vimux#Prepare()
    return 0
  endif

  let l:autoreturn = 1
  if exists("a:1")
    let l:autoreturn = a:1
  endif

  let g:VimuxLastCommand = a:command

  "let resetSequence = vimux#_VimuxOption("g:VimuxResetSequence", "q C-u")
  "call vimux#VimuxSendKeys(resetSequence)

  " Special keys
  if a:command ==? "<Enter>"
    call vimux#VimuxSendKeys("Enter")
    return 0
  elseif a:command ==? "<Clear>"
    " ^L only clears the entire screen in readline(3) applications
    " (look for "clear-screen" in the man page).
    call vimux#VimuxSendKeys("C-l")
    return 0
  else
    call vimux#VimuxSendText(a:command)
    if l:autoreturn == 1
      call vimux#VimuxSendKeys("Enter")
    endif
    return 1
  endif
endfunction

function! vimux#VimuxSendText(text)
  call vimux#VimuxSendKeys('"' . escape(a:text, '\"$') . '"')
endfunction

function! vimux#VimuxSendKeys(keys)
  if vimux#Prepare()
    call vimux#_VimuxTmux("send-keys -t ".g:VimuxRunnerIndex." -- ".a:keys)
  endif
endfunction

function! vimux#VimuxOpenRunner()
  let nearestIndex = vimux#_VimuxNearestIndex()

  if vimux#_VimuxOption("g:VimuxUseNearest", 1) == 1 && nearestIndex != -1
    let g:VimuxRunnerIndex = nearestIndex
  else
    if vimux#_VimuxRunnerType() == "pane"
      let height = vimux#_VimuxOption("g:VimuxHeight", 20)
      let orientation = vimux#_VimuxOption("g:VimuxOrientation", "v")
      call vimux#_VimuxTmux("split-window -p ".height." -".orientation)
    elseif vimux#_VimuxRunnerType() == "window"
      call vimux#_VimuxTmux("new-window")
    endif

    let g:VimuxRunnerIndex = vimux#_VimuxTmuxIndex()
    call vimux#_VimuxTmux("last-" . vimux#_VimuxRunnerType())
  endif
endfunction

function! vimux#VimuxCloseRunner()
  if exists("g:VimuxRunnerIndex")
    call vimux#_VimuxTmux("kill-" . vimux#_VimuxRunnerType()." -t ".g:VimuxRunnerIndex)
    unlet! g:VimuxRunnerIndex
  endif
endfunction

function! vimux#VimuxTogglePane()
  if exists("g:VimuxRunnerIndex")
    if vimux#_VimuxRunnerType() == "window"
        call vimux#_VimuxTmux("join-pane -d -s ".g:VimuxRunnerIndex." -p " .vimux#_VimuxOption("g:VimuxHeight", 20))
        let g:VimuxRunnerType = "pane"
    elseif vimux#_VimuxRunnerType() == "pane"
      let g:VimuxRunnerIndex=substitute(vimux#_VimuxTmux("break-pane -d -t ".g:VimuxRunnerIndex." -P -F '#{window_index}'"), "\n", "", "")
        let g:VimuxRunnerType = "window"
    endif
  endif
endfunction

function! vimux#VimuxZoomRunner()
  if exists("g:VimuxRunnerIndex")
    if vimux#_VimuxRunnerType() == "pane"
      call vimux#_VimuxTmux("resize-pane -Z -t ".g:VimuxRunnerIndex)
    elseif vimux#_VimuxRunnerType() == "window"
      call vimux#_VimuxTmux("select-window -t ".g:VimuxRunnerIndex)
    endif
  endif
endfunction

function! vimux#VimuxInspectRunner()
  call vimux#_VimuxTmux("select-".vimux#_VimuxRunnerType()." -t ".g:VimuxRunnerIndex)
  call vimux#_VimuxTmux("copy-mode")
endfunction

function! vimux#VimuxScrollUpInspect()
  call vimux#VimuxInspectRunner()
  call vimux#_VimuxTmux("last-".vimux#_VimuxRunnerType())
  call vimux#VimuxSendKeys("C-u")
endfunction

function! vimux#VimuxScrollDownInspect()
  call vimux#VimuxInspectRunner()
  call vimux#_VimuxTmux("last-".vimux#_VimuxRunnerType())
  call vimux#VimuxSendKeys("C-d")
endfunction

function! vimux#VimuxInterruptRunner()
  call vimux#VimuxSendKeys("^c")
endfunction

function! vimux#VimuxClearRunnerHistory()
  if exists("g:VimuxRunnerIndex")
    call vimux#_VimuxTmux("clear-history -t ".g:VimuxRunnerIndex)
  endif
endfunction

function! vimux#VimuxPromptCommand(...)
  let command = a:0 == 1 ? a:1 : ""
  let l:command = input(vimux#_VimuxOption("g:VimuxPromptString", "Command? "), command)
  if !empty(l:command)
    call vimux#Run(l:command)
  endif
endfunction

function! vimux#_VimuxTmux(arguments)
  let l:command = vimux#_VimuxOption("g:VimuxTmuxCommand", "tmux")
  " Prefix space to skip history
  if g:VimuxDebug
    echom "tmux> " . l:command . " " . a:arguments
  endif
  return system(" " . l:command . " " . a:arguments)
endfunction

function! vimux#_VimuxTmuxSession()
  return vimux#_VimuxTmuxProperty("#S")
endfunction

function! vimux#_VimuxTmuxIndex()
  if vimux#_VimuxRunnerType() == "pane"
    return vimux#_VimuxTmuxPaneIndex()
  else
    return vimux#_VimuxTmuxWindowIndex()
  end
endfunction

function! vimux#_VimuxTmuxPaneIndex()
  return vimux#_VimuxTmuxProperty("#I.#P")
endfunction

function! vimux#_VimuxTmuxWindowIndex()
  return vimux#_VimuxTmuxProperty("#I")
endfunction

function! vimux#_VimuxNearestIndex()
  if !exists("g:VimuxVimIndex")
    return -1
  endif

  let runner = -1
  if g:VimuxVimIndex % 2 == 0
    let runner = g:VimuxVimIndex - 1
  else
    let runner = g:VimuxVimIndex + 1
  endif

  let find = 0
  let views = split(vimux#_VimuxTmux("list-".vimux#_VimuxRunnerType()."s"), "\n")
  for view in views
    if runner == 0 + split(view, ":")[0]
      let find = 1
      let g:VimuxRunnerIndex = runner

      let m_str = matchstr(view, "x\\d\\+]")
      let g:VimuxRunnerHeight = 0 + m_str[1:-2]
    endif
  endfor

  if !find
    unlet! g:VimuxRunnerIndex
    unlet! g:VimuxRunnerHeight
    return -1
  endif

  return runner
endfunction

function! vimux#_VimuxRunnerType()
  return vimux#_VimuxOption("g:VimuxRunnerType", "pane")
endfunction

function! vimux#_VimuxOption(option, default)
  if exists(a:option)
    return eval(a:option)
  else
    return a:default
  endif
endfunction

function! vimux#_VimuxTmuxOption(option, default)
    let optstr = substitute(vimux#_VimuxTmux("showw -g | grep '".a:option."'"), '\n$', '', '')
    if !empty(optstr)
      return split(optstr, " ")[1]
    endif
    return default
endfunction

function! vimux#_VimuxTmuxProperty(property)
    return substitute(vimux#_VimuxTmux("display -p '".a:property."'"), '\n$', '', '')
endfunction

function! vimux#_VimuxHasRunner(index)
  return match(vimux#_VimuxTmux("list-".vimux#_VimuxRunnerType()."s -a"), a:index.":")
endfunction

function! vimux#execute_selection(sel)
  if a:sel
    let [lnum1, col1] = getpos("'<")[1:2]
    let [lnum2, col2] = getpos("'>")[1:2]
    let lines = getline(lnum1, lnum2)
    let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][col1 - 1:]

    let i = 0
    let l_len = len(lines) - 1
    call vimux#VimuxOpenRunner()
    if (l_len == 0)
      call vimux#Run(lines[i])
    else
      for cmd in lines
        if i == l_len
          call vimux#VimuxSendText(cmd)
        else
          call vimux#Run(cmd)
        endif

        let i += 1
      endfor
    endif
  else
    " run current line
    let aline = getline(line('.'))
    if !empty(aline)
      call vimux#Run(aline)
    endif
  endif
endfunction

function! vimux#start_insert()
  set paste | startinsert!
endfunction

function! vimux#copy_selection()
  if !vimux#Prepare()
    return
  endif

  if v:count > 0 && vimux#TmuxInfoRefresh()
    call vimux#_VimuxTmux("capture-pane "
          \ . " -S " . (g:VimuxRunnerCursorY - v:count + 1)
          \ . " -t " . g:VimuxRunnerIndex)
  else
    call vimux#_VimuxTmux("capture-pane -t ".g:VimuxRunnerIndex)
  endif

  call vimux#_VimuxTmux("save-buffer /tmp/vim.yank")
  call vimux#start_insert()
  call vimux#_VimuxTmux("paste-buffer -t ".g:VimuxVimIndex)
  "call vimux#_VimuxTmux("delete-buffer")

  redraw!
endfunction

function! vimux#_exe(cmd) abort
  try
    silent! redir => vimux_exe_ret
    silent! exe "" . a:cmd
    redir END
  finally
  endtry

  return vimux_exe_ret
endfunction

" Init {{{1
if !exists("g:VimuxVimIndex")
  let g:VimuxVimIndex = vimux#_VimuxTmuxProperty("#P")
endif

if !exists("g:VimuxRunnerIndex")
  call vimux#_VimuxNearestIndex()
endif