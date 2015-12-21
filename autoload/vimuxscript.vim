function! vimuxscript#execute_group()
  if !vimux#Prepare()
    echom "No VimxOpenRunner."
    return
  endif

  " search group's start & end
  let group_start = -1
  let group_end = -1
  let cur_line = line('.')
  let offset = 0
  while (1)
    if group_start == -1 && match(getline(cur_line - offset), "{{{\\d\\+") > -1
      let group_start = cur_line - offset + 1
    endif

    if group_end == -1 && match(getline(cur_line + offset), "}}}") > -1
      let group_end = cur_line + offset - 1
    endif

    let offset += 1
    if offset > g:VimuxGroupMaxLines
      echom "vimux execute group fail: region larger than " . g:VimuxGroupMaxLines
      return
    endif

    if group_start != -1 && group_end != -1
      break
    endif
  endwhile

  " Execute the group
  "   cmd begin with #: comment
  "   cmd end with <CR>: run command
  "   cmd end with space: send text and waiting to send your input
  "   cmd begin with eval: eval as vimscript
  "   var 'g:output': the runner command's g:output
  "   var 'g:outstr': the return of the matchstr(g:output, 'substr')
  let g:output = ""
  let g:outstr = ""
  let g:cmdstr = ""
  let g:last_cmdstr = ""

  let lines = getline(group_start, group_end)
  for cmd in lines
    let g:last_cmdstr = g:cmdstr
    let g:cmdstr = ""

    " Skip comment line, empty line
    if empty(cmd) || match(cmd, "^ \\+$") > -1 || match(cmd, "^#") > -1
      continue
    elseif match(cmd, "^<.*>") > -1
      if match(cmd, "^<return>") > -1
        return
      elseif match(cmd, "^<info>") > -1
        echom "Info:\n"
              \."  cmdstr[".g:last_cmdstr."]\n"
              \."  outstr[".g:outstr."]\n"
              \."  output[".g:output[-20:]."]\n\n"
      elseif match(cmd, "^<capture> ") > -1
        let g:VimuxGroupCaptureLine = 0 + cmd[10:]
        echom g:VimuxGroupCaptureLine
        continue
      elseif match(cmd, "^<match> ") > -1
        let g:outstr = ""
        if !empty(g:output)
          let m_str = matchstr(cmd, "|.*|$")
        endif

        if !empty(m_str[1:-2])
          let g:outstr = matchstr(g:output, m_str[1:-2])
        endif
      elseif match(cmd, "^<case> ") > -1
        let m_str = matchstr(cmd, "|.*| ")
        if match(g:outstr, m_str[1:-3]) > -1
          let g:cmdstr = cmd[(7 + len(m_str)) : ]
        endif
      elseif match(cmd, "^<eval> ") > -1
        execute cmd[7:]
      "elseif match(cmd, ' <eval> ') > -1
      "  let pos = match(cmd, ' <eval> ')
      "  call vimux#VimuxSendText(cmd[:pos])

      "  silent! redir => eval_out
      "  execute cmd[pos + 8:]
      "  redir END

      "  if len(eval_out) > 1
      "    call vimux#VimuxSendText(eval_out[1:])
      "  endif
      "  call vimux#VimuxSendKeys('Enter')
      else
        echom "Vimux exec group fail: invalid vimux command[" . cmd . "]"
      endif
    else
      let g:cmdstr = cmd
    endif

    if empty(g:cmdstr)
      continue
    endif

    " solve variable
    while match(g:cmdstr, "$<.*>") > -1
      let varstr_ = matchstr(g:cmdstr, "$<.*>")
      let varstr = varstr_[2:-2]
      if !empty(varstr)
        "strtrans()
        silent! redir => eval_out_
        execute "echo " . varstr
        redir END

        let eval_out = strtrans(eval_out_)
        echom "wilson: ".eval_out. " ". varstr_
        let g:cmdstr = substitute(g:cmdstr, "$<.*>", eval_out[2:], "")
        echom "wilson: ".g:cmdstr
      endif
    endwhile

    if empty(g:cmdstr)
      continue
    endif

    let capture = 0
    let captureRefresh = 0
    if match(g:cmdstr, " $") > -1
      let capture = 1
      if vimux#TmuxInfoRefresh()
        let captureRefresh = 1
      endif

      call vimux#VimuxSendText(g:cmdstr)
      let data = input("input# ")
      call vimux#VimuxSendText(data)
      call vimux#VimuxSendKeys("Enter")
    else
      if vimux#TmuxInfoRefresh()
        let captureRefresh = 1
      endif

      if vimux#Run(g:cmdstr)
        let capture = 1
      endif
    endif

    if capture
      " old sizes
      if captureRefresh
        let historySize = g:VimuxRunnerHistorySize
        let paneHeight = g:VimuxRunnerPaneHeight
        let cursorY = g:VimuxRunnerCursorY
      endif

      exec "sleep " . g:VimuxGroupCaptureWait . "m"

      let tmux_str = ""
      if captureRefresh && vimux#TmuxInfoRefresh()
        let delta = g:VimuxRunnerHistorySize + g:VimuxRunnerCursorY
              \ - historySize - cursorY

        let tmux_str = " -S " . (g:VimuxRunnerCursorY - delta + 1)
            \ . " -t " . g:VimuxRunnerIndex
      else
        let tmux_str = " -S " . (g:VimuxRunnerCursorY - g:VimuxGroupCaptureLine + 1)
            \ . " -t " . g:VimuxRunnerIndex
      endif

      if !empty(tmux_str)
        let g:output = vimux#_VimuxTmux("capture-pane -p" . tmux_str)

        if g:VimuxDebug
          " So we can check the output by: tmux show-buff <or> check the file
          call vimux#_VimuxTmux("capture-pane " . tmux_str)
          call vimux#_VimuxTmux("save-buffer /tmp/vim.vimux")
          "call vimux#_VimuxTmux("delete-buffer")
        endif
      endif
    endif
  endfor
endfunction
