if !exists("s:init")
    let s:init = 1
    silent! let s:log = logger#getLogger(expand('<sfile>:t'))
endif

func! s:enum(list)
    let l:enum = {}
    let idx = 0
    for item in a:list
        let l:enum[item] = idx
        let idx += 1
    endfor
    return l:enum
endf

" @return -1 stop
"          0 succ and continue next command
"          1 succ and try more process like capture output or sleep
let s:ret = s:enum(['exit','next','fail'])
let s:state = s:enum(['begin','end','vimline','vimbegin', 'vimend'])
let s:ctx = { 'init': 0,
            \ 'begin': "{{{\\d\\+",
            \ 'end': "}}}",
            \ 'begin_cmd': "",
            \ 'end_cmd': "",
            \ 'matcher': {},
            \ 'state': {},
            \
            \ 'max_line': 1000,
            \ 'cur_line': 0,
            \ 'last_cmd': '',
            \ 'exec_cmd': '',
            \ 'exec_cmd_list': [],
            \ 'cmd_out': '',
            \ 'cmd_outstr': '',
            \ }
let s:ctx_init = copy(s:ctx)

" State {{{1
let s:State = {}
func s:State.new()
    let state = copy(self)
    let state.super = state
    return state
endf

func s:State.handleLine()
    return vimuxscript#_ExecuteCmd(s:ctx.exec_cmd)
endf

func s:State.done()
    " do nothing
endf


" StateVim {{{1
let s:StateVim = {}
func s:StateVim.new()
    let state = copy(self)
    call extend(state, s:State.new(), 'keep')
    return state
endf

func s:StateVim.handleLine()
    let __func__ = 's:StateVim.handleLine() '
    silent! call s:log.trace(__func__, 'vim: '..s:ctx.exec_cmd)
    " exec s:ctx.exec_cmd
    call add(s:ctx.exec_cmd_list, s:ctx.exec_cmd)
endf

func s:StateVim.done()
    let __func__ = 's:StateVim.done() '
    let vimcode = join(s:ctx.exec_cmd_list, ' | ')
    silent! call s:log.trace(__func__, 'vim: '..vimcode)
    " exec vimcode
    call execute(vimcode)
endf


" tmux {{{1
func! vimuxscript#_open()
    if empty(s:ctx.state)
        let s:ctx.state = s:State.new()
    endif
endfunc


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
        "call vimux#VimuxOpenRunner()
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

function! vimuxscript#CallName(groupname)
    if a:groupname !=# g:VimuxGroupInit && !vimux#Prepare()
        echom "No VimxOpenRunner."
        return
    endif

    if !s:ctx.cur_line
        let s:ctx.cur_line = line('.')
    endif

    let line = search('\<' . a:groupname . '\>.\{-}{{{\d', 'wn')
    "echom a:groupname . " search=" line
    if line > 0
        let region = vimuxscript#_GetRegion(line, -1)
        if !empty(region)
            let save_line = s:ctx.cur_line
            call vimuxscript#_ExecuteRegion(region[0], region[1])
            let s:ctx.cur_line = save_line
            call cursor(s:ctx.cur_line, 1)
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
    let params = substitute(cmdstr, '^@.\{-} \(.\{-}\)$', '\1', '')

    let params = substitute(params, '^\s*\(.\{-}\)\s*$', '\1', '')
    let params = substitute(params, '^\t*\(.\{-}\)\t*$', '\1', '')

    return params
endfunction


func! vimuxscript#_GetRegion(from, to)
    let __func__ = 'vimuxscript#_GetRegion('..a:from..'~'..a:to..') '

    let f_start = -1
    let f_end = -1
    let max_end = line('$')

    silent! call s:log.trace(__func__, "begin=", s:ctx.begin, " end=", s:ctx.end)
    let f_line = a:from
    while f_start == -1 && f_line >= 0
        if match(getline(f_line), s:ctx.begin) > -1
            let f_start = f_line + 1
        endif

        let f_line -= 1
    endwhile

    let f_line = a:to != -1 ? a:to : f_start
    while f_end == -1 && f_line <= max_end
        if match(getline(f_line), s:ctx.end) > -1
            let f_end = f_line - 1
        endif

        let f_line += 1
    endwhile

    silent! call s:log.trace(__func__, "block: "..f_start."~"..f_end)
    if f_start == -1 || f_end == -1
        echoerr __func__..f_start."~".f_end.": ". getline(a:from)
        return 0
    endif

    return [f_start, f_end]
endf


function! vimuxscript#CallRegion(init)
    let __func__ = 'vimuxscript#CallRegion('..a:init..') '

    if !vimux#Prepare()
        echom "No VimxOpenRunner."
        return
    endif

    let cur_l = line('.')
    silent! call s:log.trace(__func__, "before init")
    call vimuxscript#_Init(a:init)
    silent! call s:log.trace(__func__, "after init")
    let region = vimuxscript#_GetRegion(cur_l, cur_l)
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
        silent! call s:log.trace("delta=", delta, "hist=", a:hist_pos, " curr=", curr_pos)
    elseif !empty(curr_pos)
        let tmux_str = " -S " . (curr_pos[2] - g:VimuxGroupCaptureLine + 1)
                    \ . " -t " . g:VimuxRunnerIndex
    endif

    silent! call s:log.trace('save-buff cmd-str '. tmux_str)
    if !empty(tmux_str)
        let s:ctx.cmd_out = vimux#_VimuxTmux("capture-pane -p" . tmux_str)

        silent! call s:log.trace('save-buff args: '. a:0)
        if g:VimuxDebug || a:0
            " So we can check the output by: tmux show-buff <or> check the file
            call vimux#_VimuxTmux("capture-pane " . tmux_str)

            let fname = '/tmp/vim.vimux'
            if a:0
                let fname = a:1
            endif
            silent! call s:log.trace('save-buff to '. fname)
            call vimux#_VimuxTmux("save-buffer ".fname)
            "call vimux#_VimuxTmux("delete-buffer")
        endif

        silent! call s:log.trace('Output: '. s:ctx.cmd_out)
        return s:ctx.cmd_out
    endif

    return ""
endfunction

function! vimuxscript#_NoWait()
    let g:VimuxGroupCaptureWait = 0
    let g:VimuxGroupCommandPause = 0
endfunction


" Inner script command:
" <return> <info> <capture> <attach>
" <call> <label> <goto>
" <match> <case>
" <eval>
func! vimuxscript#_ExecuteInnnerAction(cmdline)
    let __func__ = 'vimuxscript#_ExecuteInnnerAction() '

    let cmdline = vimuxscript#_ParseVars(a:cmdline)
    let params = vimuxscript#_GetParams(cmdline)

    if match(cmdline, "^@return") > -1
        return s:ret.exit
    elseif match(cmdline, "^@exit") > -1
        return s:ret.exit
    elseif match(cmdline, "^@begin ") > -1
        "let s:ctx.begin = trim(params, "\'\"")
        let s:ctx.begin = params
        silent! call s:log.trace(__func__, 'begin: '. params)
        return s:ret.next
    elseif match(cmdline, "^@end ") > -1
        "let s:ctx.end = trim(params, "\'\"")
        let s:ctx.end = params
        silent! call s:log.trace(__func__, 'end: '. params)
        return s:ret.next
    elseif match(cmdline, "^@begin_cmd ") > -1
        let s:ctx.begin_cmd = params
        return s:ret.next
    elseif match(cmdline, "^@end_cmd ") > -1
        let s:ctx.end_cmd = params
        return s:ret.next
    elseif match(cmdline, "^@vim ") > -1
        exec params
        silent! call s:log.trace(__func__, 'vim: '. params)
        return s:ret.next
    elseif match(cmdline, "^@vimbegin") > -1
        execute params
        call s:ctx.state.done()
        unlet s:ctx.state
        let s:ctx.state = s:StateVim.new()
        return s:ret.next
    elseif match(cmdline, "^@vimend") > -1
        call s:ctx.state.done()
        unlet s:ctx.state
        let s:ctx.state = s:State.new()
        return s:ret.next
    elseif match(cmdline, "^@info ") > -1
        echom "Info:\n"
                    \."  cmdstr["..g:last_cmdstr.."]\n"
                    \."  outstr["..s:ctx.cmd_outstr.."]\n"
                    \."  output[".s:ctx.cmd_out[-20:]."]\n\n"
        return s:ret.next
    elseif match(cmdline, "^@capture ") > -1
        let g:VimuxGroupCaptureLine = 0 + params
        return s:ret.next
    elseif match(cmdline, "^@attach ") > -1
        call vimux#TmuxAttach(params)
        return s:ret.next
    elseif match(cmdline, "^@call ") > -1
        call vimuxscript#CallName(params)
        return s:ret.next
    elseif match(cmdline, "^@sleep ") > -1
        exec 'sleep '..params
        return s:ret.next
    elseif match(cmdline, "^@label ") > -1
        return s:ret.next
    elseif match(cmdline, "^@goto ") > -1
        let l_label = search('@label.\{-}' . params, 'nw')
        if l_label > 0
            let s:ctx.cur_line = l_label + 1
            3sleep
            return s:ret.next
        endif

        echoerr "fail: " . cmdline
    elseif match(cmdline, "^@match ") > -1
        let matcher = split(params, '=>')
        if len(matcher) == 2
            let mt = trim(matcher[0], "\'\" ")
            let do = trim(matcher[1], "\'\" ")
            silent! call s:log.trace(__func__, 'add matcher: when=', mt, " do=", do)
            let s:ctx.matcher[mt] = do
        else
            silent! call s:log.trace(__func__, 'matcher should be "match" => "macro", fail: ', matcher)
        endif

    elseif match(cmdline, "^@matchold ") > -1
        let s:ctx.cmd_outstr = ""
        let s:ctx.cmd_out = ""

        if !exists("g:hist_pos")
            echoerr "no g:hist_pos fail: " . cmdline
            return s:ret.exit
        endif

        if empty(params)
            echoerr "no params fail: " . cmdline
            return s:ret.exit
        endif

        let outer_count = 0
        while empty(s:ctx.cmd_outstr) && outer_count < 100
            let outer_count += 1

            let l_count = 0
            while empty(s:ctx.cmd_out) && l_count < 100
                let l_count += 1

                if g:VimuxGroupCaptureWait > 0
                    exec "sleep " . g:VimuxGroupCaptureWait . "m"
                endif
                call vimuxscript#_Capture(g:hist_pos)
                let g:hist_pos = vimuxscript#_TmuxInfoRefresh()
            endwhile
            if l_count == 100 || empty(s:ctx.cmd_out)
                echoerr "capture no output after 10s: " . cmdline
                return s:ret.exit
            endif

            let out_lines = split(s:ctx.cmd_out, "\n")
            for out_line in out_lines
                let s:ctx.cmd_outstr = matchstr(out_line, params)
                silent! call s:log.trace(l:__func__, "out_line=" . out_line . " params=" . params. " result[s:ctx.cmd_outstr]=" . s:ctx.cmd_outstr)
                if !empty(s:ctx.cmd_outstr)
                    break
                endif
            endfor

            if empty(s:ctx.cmd_outstr)
                let s:ctx.cmd_outstr = matchstr(s:ctx.cmd_out, params)
                silent! call s:log.trace(l:__func__, "s:ctx.cmd_out=" . s:ctx.cmd_out . " params=" . params. " result[s:ctx.cmd_outstr]=" . s:ctx.cmd_outstr)
            endif

            if empty(s:ctx.cmd_outstr)
                if g:VimuxGroupCaptureWait > 0
                    exec "sleep " . g:VimuxGroupCaptureWait . "m"
                endif
                let s:ctx.cmd_out = ""
            endif
        endwhile

        if empty(s:ctx.cmd_outstr)
            echoerr "match fail after 10s: " . cmdline
            return s:ret.exit
        else
            return s:ret.next
        endif
    elseif match(cmdline, "^@case ") > -1
        let m_str = matchstr(cmdline, "|.*| ")
        if empty(m_str)
            echoerr "{<case> |case-str| command} format error: " . cmdline
            return s:ret.exit
        endif

        let g:outstr2 = matchstr(s:ctx.cmd_outstr, m_str[1:-3])
        if !empty(g:outstr2)
            let s:ctx.exec_cmd = cmdline[(7 + len(m_str)) : ]
            call vimuxscript#_ExecuteCmd(s:ctx.exec_cmd)
            return s:ret.next
        endif
    elseif match(cmdline, "^@eval ") > -1
        execute params
        return s:ret.next
    elseif match(cmdline, "^@sleep ") > -1
        exec "sleep " . params
        return s:ret.next
    else
        let s:ctx.exec_cmd = cmdline
        "echom 'Vimux exec group fail: invalid vimux command[' . cmdline . ']'
        return s:ret.fail
    endif
endf


function! vimuxscript#_ParseVars(cmdline_)
    let __func__ = 'vimuxscript#_ParseVars() '

    silent! call s:log.trace(__func__, a:cmdline_)
    if empty(a:cmdline_) | return 0 | endif
    let cmdline = a:cmdline_
    while match(cmdline, "$<.*>") > -1
        let varstr_ = matchstr(cmdline, "$<.*>")
        let varstr = varstr_[2:-2]
        if !empty(varstr)
            "strtrans()
            redir => eval_out_
            silent! execute "echo " . varstr
            redir END

            let eval_out = strtrans(eval_out_)
            silent! call s:log.trace(__func__, "eval: ".eval_out. " ". varstr_)
            let cmdline = substitute(cmdline, "$<.*>", eval_out[2:], "")
            silent! call s:log.trace(__func__, "cmd: ".cmdline)
        endif
    endwhile

    return cmdline
endfunction


" Have 2 specail case:
" endwith_space
" match apply macro
func! vimuxscript#_ExecuteCmd(cmdline_)
    let __func__ = 'vimuxscript#_ExecuteCmd() '

    "silent! call s:log.trace(__func__, cmdline_)
    let cmdline = vimuxscript#_ParseVars(a:cmdline_)
    if empty(cmdline) | return 0 | endif
    "silent! call s:log.trace(__func__, cmdline_)

    for [mt, do_macro] in items(s:ctx.matcher)
        " silent! call s:log.trace(__func__, "cmdline", cmdline)
        " silent! call s:log.trace(__func__, "mt=", mt, " macro=", do_macro)
        if match(cmdline, mt) > -1
            call writefile([cmdline], glob('/tmp/vim.tmp'))
            call system("ex --clean /tmp/vim.tmp -c 'normal "..do_macro.."' -c wq")
            let lines = readfile(glob('/tmp/vim.tmp'))
            silent! call s:log.trace(__func__, "@[", mt, "] macro=", do_macro)
            if len(lines) > 0
                let cmdline = lines[0]
            endif
        endif
    endfor

    if len(cmdline) == 0 | return 0 | endif
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

        if g:VimuxGroupCommandPause > 0
            exec "sleep " . g:VimuxGroupCommandPause . "m"
        endif
        return 1
    else
        if vimux#Run(cmdline)
            let capture = 1
            if g:VimuxGroupCommandPause > 0
                exec "sleep " . g:VimuxGroupCommandPause . "m"
            endif
            return 1
        endif
    endif

    return 0
endf


func! vimuxscript#_Init(forceInit)
    if a:forceInit
        let s:ctx = deepcopy(s:ctx_init)
    endif
    if s:ctx.init | return | endif
    let s:ctx.init = 1
    call vimuxscript#CallName(g:VimuxGroupInit)
endf

" @return -1 stop
"          0 succ and continue next command
"          1 succ and try more process like capture output or sleep
function! vimuxscript#_ExecuteOneLine(cmdline_)
    let __func__ = 'vimuxscript#_ExecuteOneLine() '

    let cmdline = a:cmdline_
    silent! call s:log.trace(__func__, cmdline)
    if !exists("g:vimuxscript_init")
        let g:vimuxscript_init = getftime(expand('%'))
        call vimuxscript#CallName(g:VimuxGroupInit)
    elseif g:vimuxscript_init != getftime(expand('%'))
        let g:vimuxscript_init = getftime(expand('%'))
        call vimuxscript#CallName(g:VimuxGroupInit)
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
        \ || match(cmdline, "^##") > -1
        return s:ret.next
    elseif match(cmdline, "^@") > -1
        let ret = vimuxscript#_ExecuteInnnerAction(cmdline)
        if (ret < 1)
            return s:ret.exit
        endif
    else
        let s:ctx.exec_cmd = cmdline
    endif

    if len(s:ctx.exec_cmd) == 0 | return s:ret.next | endif
    call s:ctx.state.handleLine()
endfunction


function! vimuxscript#_ExecuteRegion(start, end)
    let __func__ = 'vimuxscript#_ExecuteRegion() '

    if !vimux#Prepare()
        echom "No VimxOpenRunner."
        return
    endif
    call vimuxscript#_open()

    " Execute the group
    "   cmd begin with #: comment
    "   cmd end with <CR>: run command
    "   cmd end with space: send text and waiting to send your input
    "   cmd begin with eval: eval as vimscript
    "   var 's:ctx.cmd_out': the runner command's s:ctx.cmd_out
    "   var 's:ctx.cmd_outstr': the return of the matchstr(s:ctx.cmd_out, 'substr')
    let s:ctx.cmd_out = ""
    let s:ctx.cmd_outstr = ""
    let s:ctx.exec_cmd = ''
    let s:ctx.last_cmd = ""

    let count = 0
    let s:ctx.cur_line = a:start
    call vimuxscript#_ExecuteOneLine(s:ctx.begin_cmd)
    while (s:ctx.cur_line <= a:end && count < s:ctx.max_line)
        let count += 1
        let cmd = getline(s:ctx.cur_line)
        call cursor(s:ctx.cur_line, 1)
        let s:ctx.cur_line += 1
        "echom cmd

        let g:last_cmdstr = s:ctx.exec_cmd
        let s:ctx.exec_cmd = ""

        let ret = vimuxscript#_ExecuteOneLine(cmd)
        if (ret == 0)
            continue
        elseif (ret == 1)
            " more action
        elseif (ret == -1)
            break
        endif
    endwhile
    call vimuxscript#_ExecuteOneLine(s:ctx.end_cmd)

endfunction

