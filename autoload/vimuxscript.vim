" @return valid check use empty()
function! vimuxscript#_TmuxInfoRefresh()
  if !exists("g:VimuxRunnerIndex")
    echom "TmuxInfoRefresh fail: No VimxOpenRunner."
    return 0
  endif

  let views = split(vimux#_VimuxTmux("list-".vimux#_VimuxRunnerType()
        \."s -F '#{pane_index} #{history_size} #{pane_height} #{cursor_y}'"), "\n")

  for view in views
    let sizes = split(view, ' ')
    if sizes[0] == g:VimuxRunnerIndex
      return [0+sizes[1], 0+sizes[2], 0+sizes[3]]
    endif
  endfor

  return 0
endfunction

function! vimuxscript#execute_selection(sel)
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

function! vimuxscript#_StartInsert(yankfile)
  execute "read " . a:yankfile
endfunction

function! vimuxscript#StartCopy()
  let g:VimuxCopyPosStart = vimuxscript#_TmuxInfoRefresh()
  echo "vimux copy start set succ ..."
endfunction

function! vimuxscript#Copy()
  if !vimux#Prepare()
    return
  endif

  let curr_pos = vimuxscript#_TmuxInfoRefresh()
  if v:count > 0 && !empty(curr_pos)
    if g:VimuxDebug
      echom "vimux copy mode count: " . v:count
    endif

    call vimux#_VimuxTmux("capture-pane "
          \ . " -S " . (curr_pos[2] - v:count + 1)
          \ . " -t " . g:VimuxRunnerIndex)
  elseif exists("g:VimuxCopyPosStart") && !empty(g:VimuxCopyPosStart)
    let delta = curr_pos[0] + curr_pos[2]
          \ - g:VimuxCopyPosStart[0] - g:VimuxCopyPosStart[2]

    if g:VimuxDebug
      echom "vimux copy mode start: " . v:count
    endif

    let tmux_str = " -S " . (curr_pos[2] - delta + 1)
        \ . " -t " . g:VimuxRunnerIndex

    call vimux#_VimuxTmux("capture-pane " . tmux_str)
  else
    if g:VimuxDebug
      echom "vimux copy mode screen: " . v:count
    endif
    call vimux#_VimuxTmux("capture-pane -t ".g:VimuxRunnerIndex)
  endif

  call vimux#_VimuxTmux("save-buffer /tmp/vim.yank")
  call vimuxscript#_StartInsert("/tmp/vim.yank")
  "call vimux#_VimuxTmux("paste-buffer -t ".g:VimuxVimIndex)
  "call vimux#_VimuxTmux("delete-buffer")

  unlet! g:VimuxCopyPosStart
  redraw!
endfunction

function! vimuxscript#_exe(cmd) abort
  try
    silent! redir => vimux_exe_ret
    silent! exe "" . a:cmd
    redir END
  finally
  endtry

  return vimux_exe_ret
endfunction

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
        let g:cmdstr = cmd
        "echom 'Vimux exec group fail: invalid vimux command[' . cmd . ']'
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
    let hist_pos = []
    if match(g:cmdstr, " $") > -1
      let capture = 1
      let hist_pos = vimuxscript#_TmuxInfoRefresh()

      call vimux#VimuxSendText(g:cmdstr)
      let data = input("input# ")
      call vimux#VimuxSendText(data)
      call vimux#VimuxSendKeys("Enter")
    else
      let hist_pos = vimuxscript#_TmuxInfoRefresh()

      if vimux#Run(g:cmdstr)
        let capture = 1
      endif
    endif

    if capture
      exec "sleep " . g:VimuxGroupCaptureWait . "m"

      let tmux_str = ""
      let curr_pos = vimuxscript#_TmuxInfoRefresh()
      if !empty(hist_pos) && !empty(curr_pos)
        let delta = curr_pos[0] + curr_pos[2]
              \ - hist_pos[0] - hist_pos[2]

        let tmux_str = " -S " . (curr_pos[2] - delta + 1)
            \ . " -t " . g:VimuxRunnerIndex
      else
        let tmux_str = " -S " . (curr_pos[2] - g:VimuxGroupCaptureLine + 1)
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
