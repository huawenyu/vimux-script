" @return valid check use empty()
function! vimuxscript#_TmuxInfoRefresh()
    if !exists("g:VimuxRunnerIndex")
        echom "TmuxInfoRefresh fail: No VimxOpenRunner."
        return []
    endif

    let views = split(vimux#_VimuxTmux("list-".vimux#_VimuxRunnerType()
                \."s -sF '#{window_index}.#{pane_index} #{history_size} #{pane_height} #{cursor_y}'"), "\n")

    for view in views
        let sizes = split(view, ' ')
        if sizes[0] == g:VimuxRunnerIndex
            return [0+sizes[1], 0+sizes[2], 0+sizes[3]]
        endif
    endfor

    return []
endfunction

function! vimuxscript#ExecuteSelection(sel)
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
                    call vimuxscript#_ExecuteOneLine(cmd)
                endif

                let i += 1
            endfor
        endif
    else
        " run current line
        call vimuxscript#_ExecuteOneLine(getline(line('.')))
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

function! vimuxscript#_Exe(cmd) abort
    try
        silent! redir => vimux_exe_ret
        silent! exe "" . a:cmd
        redir END
    finally
    endtry

    return vimux_exe_ret
endfunction

function! vimuxscript#ExecuteGroupByname(groupname)
    if a:groupname !=# g:VimuxGroupInit && !vimux#Prepare()
        echom "No VimxOpenRunner."
        return
    endif

    if !exists("g:sp_vimux")
        let g:sp_vimux = line('.')
    endif

    let line = search('\<' . a:groupname . '\>.\{-}{{{\d', 'wn')
    "echom a:groupname . " search=" line
    if line > 0
        let region = vimuxscript#_GetRegion(line)
        if !empty(region)
            let sp_old = g:sp_vimux
            call vimuxscript#_ExecuteRegion(region[0], region[1])
            let g:sp_vimux = sp_old
            call cursor(g:sp_vimux, 1)
            return
        endif
    endif

    if a:groupname !=# g:VimuxGroupInit
        echoerr 'Execute Byname fail: ' . a:groupname
    endif
endfunction

function! vimuxscript#_GetParams(cmdstr)
    " Trim
    let cmdstr = substitute(a:cmdstr, '^\s*\(.\{-}\)\s*$', '\1', '')
    let cmdstr = substitute(cmdstr, '^\t*\(.\{-}\)\t*$', '\1', '')

    " Get params
    let params = substitute(cmdstr, '^<.\{-}>\(.\{-}\)$', '\1', '')

    let params = substitute(params, '^\s*\(.\{-}\)\s*$', '\1', '')
    let params = substitute(params, '^\t*\(.\{-}\)\t*$', '\1', '')

    return params
endfunction

function! vimuxscript#_GetRegion(linenum)
    let group_start = -1
    let group_end = -1
    let max_end = line('$')

    let find_line = a:linenum
    while group_start == -1 && find_line >= 0
        if match(getline(find_line), "{{{\\d\\+") > -1
            let group_start = find_line + 1
        endif

        let find_line -= 1
    endwhile

    let find_line = a:linenum
    while group_end == -1 && find_line <= max_end
        if match(getline(find_line), "}}}") > -1
            let group_end = find_line - 1
        endif

        let find_line += 1
    endwhile

    if group_start == -1 || group_end == -1
        echoerr "Execute GetRegion fail, line=".a:linenum." ".group_start."~".group_end.": ". getline(a:linenum)
        return 0
    endif

    return [group_start, group_end]
endfunction

function! vimuxscript#ExecuteGroup()
    if !vimux#Prepare()
        echom "No VimxOpenRunner."
        return
    endif

    let region = vimuxscript#_GetRegion(line("."))
    if !empty(region)
        call vimuxscript#_ExecuteRegion(region[0], region[1])
    endif
endfunction

function! vimuxscript#_Capture(hist_pos, ...)
    let tmux_str = ""
    let curr_pos = vimuxscript#_TmuxInfoRefresh()
    if !empty(a:hist_pos) && !empty(curr_pos)
        let delta = curr_pos[0] + curr_pos[2]
                    \ - a:hist_pos[0] - a:hist_pos[2]

        let tmux_str = " -S " . (curr_pos[2] - delta + 1)
                    \ . " -t " . g:VimuxRunnerIndex
        call Decho("delta=", delta, "hist=", a:hist_pos, " curr=", curr_pos)
    elseif !empty(curr_pos)
        let tmux_str = " -S " . (curr_pos[2] - g:VimuxGroupCaptureLine + 1)
                    \ . " -t " . g:VimuxRunnerIndex
    endif

    Decho "wilson save-buff cmd-str " . tmux_str
    if !empty(tmux_str)
        let g:output = vimux#_VimuxTmux("capture-pane -p" . tmux_str)

        Decho "wilson save-buff args " . a:0
        if g:VimuxDebug || a:0
            " So we can check the output by: tmux show-buff <or> check the file
            call vimux#_VimuxTmux("capture-pane " . tmux_str)

            let fname = '/tmp/vim.vimux'
            if a:0
                let fname = a:1
            endif
            Decho "wilson save-buff to " . fname
            call vimux#_VimuxTmux("save-buffer ".fname)
            "call vimux#_VimuxTmux("delete-buffer")
        endif

        Decho g:output
        return g:output
    endif

    return ""
endfunction

" Inner script command:
" <return> <info> <capture> <attach>
" <call> <label> <goto>
" <match> <case>
" <eval>
function! vimuxscript#_ExecuteInnnerAction(cmdline)
    let cmdline = vimuxscript#_ParseVars(a:cmdline)
    let params = vimuxscript#_GetParams(cmdline)

    if match(cmdline, "^<return>") > -1
        return -1
    elseif match(cmdline, "^<let>") > -1
        execute "let " . params
        Decho "wilson let " . params
        return 0
    elseif match(cmdline, "^<info>") > -1
        echom "Info:\n"
                    \."  cmdstr[".g:last_cmdstr."]\n"
                    \."  outstr[".g:outstr."]\n"
                    \."  output[".g:output[-20:]."]\n\n"
        return 0
    elseif match(cmdline, "^<capture> ") > -1
        let g:VimuxGroupCaptureLine = 0 + params
        return 0
    elseif match(cmdline, "^<attach> ") > -1
        call vimux#TmuxAttach(params)
        return 0
    elseif match(cmdline, "^<call> ") > -1
        call vimuxscript#ExecuteGroupByname(params)
        return 0
    elseif match(cmdline, "^<label> ") > -1
        return 0
    elseif match(cmdline, "^<goto> ") > -1
        let l_label = search('<label>.\{-}' . params, 'nw')
        if l_label > 0
            let g:sp_vimux = l_label + 1
            3sleep
            return 0
        endif

        echoerr "fail: " . cmdline
    elseif match(cmdline, "^<match> ") > -1
        let g:outstr = ""
        let g:output = ""

        if !exists("g:hist_pos")
            echoerr "no g:hist_pos fail: " . cmdline
            return -1
        endif

        if empty(params)
            echoerr "no params fail: " . cmdline
            return -1
        endif

        let outer_count = 0
        while empty(g:outstr) && outer_count < 100
            let outer_count += 1

            let l_count = 0
            while empty(g:output) && l_count < 100
                let l_count += 1

                exec "sleep " . g:VimuxGroupCaptureWait . "m"
                call vimuxscript#_Capture(g:hist_pos)
                let g:hist_pos = vimuxscript#_TmuxInfoRefresh()
            endwhile
            if l_count == 100 || empty(g:output)
                echoerr "capture no output after 10s: " . cmdline
                return -1
            endif

            let out_lines = split(g:output, "\n")
            for out_line in out_lines
                let g:outstr = matchstr(out_line, params)
                Decho "out_line=" . out_line . " params=" . params. " result[g:outstr]=" . g:outstr
                if !empty(g:outstr)
                    break
                endif
            endfor

            if empty(g:outstr)
                let g:outstr = matchstr(g:output, params)
                Decho "g:output=" . g:output . " params=" . params. " result[g:outstr]=" . g:outstr
            endif

            if empty(g:outstr)
                exec "sleep " . g:VimuxGroupCaptureWait . "m"
                let g:output = ""
            endif
        endwhile

        if empty(g:outstr)
            echoerr "match fail after 10s: " . cmdline
            return -1
        else
            return 0
        endif
    elseif match(cmdline, "^<case> ") > -1
        let m_str = matchstr(cmdline, "|.*| ")
        if empty(m_str)
            echoerr "{<case> |case-str| command} format error: " . cmdline
            return -1
        endif

        let g:outstr2 = matchstr(g:outstr, m_str[1:-3])
        if !empty(g:outstr2)
            let g:cmdstr = cmdline[(7 + len(m_str)) : ]
            call vimuxscript#_ExecuteCmd(g:cmdstr)
            return 0
        endif
    elseif match(cmdline, "^<eval> ") > -1
        execute params
        return 0
    elseif match(cmdline, "^<sleep> ") > -1
        exec "sleep " . params
        return 0
    else
        let g:cmdstr = cmdline
        "echom 'Vimux exec group fail: invalid vimux command[' . cmdline . ']'
        return 1
    endif
endfunction

function! vimuxscript#_ParseVars(cmdline_)
    if empty(a:cmdline_)
        return 0
    endif
    let cmdline = a:cmdline_

    " solve variable
    Decho 'wilson executecmd: ' . cmdline
    while match(cmdline, "$<.*>") > -1
        let varstr_ = matchstr(cmdline, "$<.*>")
        let varstr = varstr_[2:-2]
        if !empty(varstr)
            "strtrans()
            redir => eval_out_
            silent! execute "echo " . varstr
            redir END

            let eval_out = strtrans(eval_out_)
            Decho "wilson: ".eval_out. " ". varstr_
            let cmdline = substitute(cmdline, "$<.*>", eval_out[2:], "")
            Decho "wilson: ".cmdline
        endif
    endwhile

    return cmdline
endfunction

function! vimuxscript#_ExecuteCmd(cmdline_)
    let cmdline = vimuxscript#_ParseVars(a:cmdline_)

    if empty(cmdline)
        return 0
    endif

    " Tmux Run
    let endwith_space = 0
    let capture = 0
    let g:hist_pos = vimuxscript#_TmuxInfoRefresh()
    if endwith_space
        let capture = 1

        call vimux#VimuxSendText(cmdline)
        let data = input("input# ")
        call vimux#VimuxSendText(data)
        call vimux#VimuxSendKeys("Enter")

        exec "sleep " . g:VimuxGroupCommandPause . "m"
        return 1
    else
        if vimux#Run(cmdline)
            let capture = 1
            exec "sleep " . g:VimuxGroupCommandPause . "m"
            return 1
        endif
    endif

    return 0
endfunction

" @return -1 stop
"          0 succ and continue next command
"          1 succ and try more process like capture output or sleep
function! vimuxscript#_ExecuteOneLine(cmdline_)
    let cmdline = a:cmdline_

    if !exists("g:vimuxscript_init")
        let g:vimuxscript_init = getftime(expand('%'))
        call vimuxscript#ExecuteGroupByname(g:VimuxGroupInit)
    elseif g:vimuxscript_init != getftime(expand('%'))
        let g:vimuxscript_init = getftime(expand('%'))
        call vimuxscript#ExecuteGroupByname(g:VimuxGroupInit)
    endif

    " Trim space and tab
    if match(cmdline, " $") > -1
        let endwith_space = 1
    endif
    let cmdline = substitute(cmdline, '^\s*\(.\{-}\)\s*$', '\1', '')
    let cmdline = substitute(cmdline, '^\t*\(.\{-}\)\t*$', '\1', '')

    " Skip comment line, empty line
    if empty(cmdline)
        \ || match(cmdline, "^ \\+$") > -1
        \ || match(cmdline, "^#") > -1
        \ || match(cmdline, "^\"") > -1
        return 0
    elseif match(cmdline, "^<.*>") > -1
        let ret = vimuxscript#_ExecuteInnnerAction(cmdline)
        " Have execute cmdstr
        if (ret < 1)
            return ret
        endif
    else
        let g:cmdstr = cmdline
    endif

    return vimuxscript#_ExecuteCmd(g:cmdstr)
endfunction

function! vimuxscript#_ExecuteRegion(start, end)
    if !vimux#Prepare()
        echom "No VimxOpenRunner."
        return
    endif

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

    let l_count = 0
    let g:sp_vimux = a:start
    while (g:sp_vimux <= a:end && l_count < 1000)
        let l_count += 1
        let cmd = getline(g:sp_vimux)
        call cursor(g:sp_vimux, 1)
        let g:sp_vimux += 1
        "echom cmd

        let g:last_cmdstr = g:cmdstr
        let g:cmdstr = ""

        let ret = vimuxscript#_ExecuteOneLine(cmd)
        if (ret == 0)
            continue
        elseif (ret == 1)
            " more action
        elseif (ret == -1)
            return
        endif

    endwhile

endfunction
