"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Vim plugin for interface to gdb from cterm
" Last change: 2010 Mar 29
" Maintainer: M Sureshkumar (m.sureshkumar@yahoo.com)
"
" Feedback welcome.
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Prevent multiple loading, allow commenting it out
if exists("loaded_vimgdb")
	finish
endif

let loaded_vimgdb = 1

" import from gdb-dashboard
"let g:tmux_gdb = ""
"let g:tmux_gdb_dir = ""
let s:gdb_servername = "GDB.SOURCE"

let s:vimgdb_running = 0
let s:gdb_win_hight = 2
let s:gdb_output_width = 10

let s:gdb_buf_name = "__GDB_WINDOW__"
let s:gdb_buf_registers = "/tmp/gdb/registers"
let s:gdb_buf_assembly = "/tmp/gdb/assembly"
let s:gdb_buf_memory = "/tmp/gdb/memory"
let s:gdb_buf_stack = "/tmp/gdb/stack"
let s:gdb_buf_breakpoints = "/tmp/gdb/breakpoints"
let s:gdb_buf_thread = "/tmp/gdb/threads"
let s:gdb_buf_expressions = "/tmp/gdb/expressions"
let s:gdb_buf_history = "/tmp/gdb/history"
let s:gdb_buf_output = "/tmp/gdb/out"
let s:gdb_capture = "/tmp/gdb/capture"

let s:cur_line_id = 9999
let s:prv_line_id = 9998
let s:max_break_point = 0
let s:gdb_client = "vimgdb_msg"

" This used to be in Gdb_interf_init, but older vims crashed on it
highlight DebugBreak guibg=darkred guifg=white ctermbg=darkred ctermfg=white
highlight DebugStop guibg=lightgreen guifg=white ctermbg=lightgreen ctermfg=white
sign define breakpoint linehl=DebugBreak
sign define current linehl=DebugStop

function! s:Gdb_buf_split(buf_name, size, pos)
    let bufnum = bufnr(a:buf_name)

    if bufnum == -1
        " Create a new buffer
        let wcmd = a:buf_name
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    exe 'silent! '.a:pos.' '.a:size. ' split ' . wcmd
endfunction

function! s:Gdb_attach(tmux_gdb)
	let g:tmux_gdb = a:tmux_gdb
	echom "GdbAttach ".g:tmux_gdb.", reset ':GdbAttach 1.4' which tmux <window-index>.<pane-index>"
endfunction

" Get ready for communication
function! s:Gdb_interf_init(tmux_gdb, vim_servername, out_dir)

	call s:Gdb_shortcuts()

	""hi CursorLine cterm=NONE ctermbg=darkred ctermfg=white

	""command -nargs=+ Gdb	:call Gdb_command(<q-args>, v:count)
	""call s:Gdb_buf_split(s:gdb_buf_name, s:gdb_win_hight, "botright")
	""call s:Gdb_buf_split(s:gdb_buf_output, s:gdb_output_width, "topright")

    "" Mark the buffer as a scratch buffer
    "setlocal buftype=nofile
    "setlocal bufhidden=delete
    "setlocal noswapfile
    "setlocal wrap
    "setlocal nobuflisted
    "setlocal nonumber

    "augroup VimGdbAutoCommand
	"	autocmd WinEnter <buffer> call s:EnterGdbBuf()
	"	autocmd WinLeave <buffer> stopi
    "augroup end

    "inoremap <buffer> <silent> <CR> <ESC>o<ESC>:call <SID>Gdb_command(getline(line(".")-1))<CR>
	"inoremap <buffer> <silent> <TAB> <C-P>
	"nnoremap <buffer> <silent> : <C-W>p:

	if exists("v:servername") && v:servername != a:vim_servername
		echoerr "Vim Gdb init fail: servername should be " . a.vim_servername
		return
	endif

	call s:Gdb_attach(a:tmux_gdb)

	let g:tmux_gdb_dir = a:out_dir
	echom "Gdb's output dir: ".g:tmux_gdb_dir

	"startinsert
	let s:vimgdb_running = 1

	"wincmd p
endfunction

function s:EnterGdbBuf()
	return

	if !s:vimgdb_running
		return
	endif
" if(winnr("$") == 1)
" 	quit
" endif
	$
	if ! (getline(".") =~ '^\s*$')
		normal o
	endif
	start
endfunction

function s:Gdb_interf_close()
	if !s:vimgdb_running
		return
	endif

	let s:vimgdb_running = 0
	sign unplace *
	let s:Breakpoint = {}
	let s:cur_line_id = 9999
	let s:prv_line_id = 9998

	" If gdb window is open then close it.
	let winnum = bufwinnr(s:gdb_buf_name)
	if winnum != -1
		exe winnum . 'wincmd w'
		quit
	endif

    silent! autocmd! VimGdbAutoCommand
endfunction

function s:Gdb_Disp_Line(file, line)
	let cur_win = winnr()
	let gdb_win = bufwinnr(s:gdb_buf_name)

	if cur_win == gdb_win
		wincmd p
	endif

	if bufname("%") != a:file
		if !bufexists(a:file)
			if !filereadable(a:file)
				return
			endif
			execute 'e +set\ nomodifiable '.a:file
		else
			execute 'b ' . bufname(a:file)
		endif
	endif

	"silent! foldopen!
	execute a:line
	call winline()
	execute cur_win.'wincmd w'
endfunction

function s:Gdb_Bpt(id, file, line)
	call s:Gdb_Disp_Line(a:file, a:line)
	execute "sign unplace ". a:id
	execute "sign place " .  a:id ." name=breakpoint line=".a:line." buffer=".bufnr(a:file)
	let s:BptList_{a:id}_file = bufname(a:file)
	let s:BptList_{a:id}_line = a:line
	if a:id > s:max_break_point
		let s:max_break_point = a:id
	endif
endfunction

function s:Gdb_NoBpt(id)
	if(exists('s:BptList_'. a:id . '_file'))
		unlet s:BptList_{a:id}_file
		unlet s:BptList_{a:id}_line

		if a:id == s:max_break_point
			let s:max_break_point = a:id - 1
		endif

		execute "sign unplace ". a:id
	endif
endfunction

function s:Gdb_CurrFileLine(file, line)
	call s:Gdb_Disp_Line(a:file, a:line)

	let temp = s:cur_line_id
	let s:cur_line_id = s:prv_line_id
	let s:prv_line_id = temp

	" place the next line before unplacing the previous 
	" otherwise display will jump
	execute "sign place " .  s:cur_line_id ." name=current line=".a:line." file=".a:file
	execute "sign unplace ". s:prv_line_id
endf

function s:Gdb_command(cmd)
	if s:vimgdb_running == 0
		echo "VIMGDB is not running"
		return
	endif

	if match (a:cmd, '^\s*$') != -1
		return
	endif

	let cur_win = winnr()
	let gdb_win = bufwinnr(s:gdb_buf_name)

	let lines = ""
	let out_count = 0

	let cmd_str = a:cmd
	if cmd_str == "until"
		let cmd_str = cmd_str." ".line('.')
	endif

	if exists("g:tmux_gdb")
		call vimux#TmuxAttach2(g:tmux_gdb)
		let hist_pos = vimuxscript#_TmuxInfoRefresh()
		call vimux#Run(cmd_str)
		call Decho("wilson try to call catpure to file ", s:gdb_capture)
		let lines = vimuxscript#_Capture(hist_pos, s:gdb_capture)
		call s:Gdb_refresh_window(s:gdb_capture)

		let fname = matchstr(lines, '\v at \zs(.*):\d+\ze\n')
		"echo fname
		if !empty(fname)
			let finfo = split(join(split(fname, '\n'), ''), ':')
			"echo finfo
			if len(finfo) >= 2
				call s:Gdb_refresh_source(finfo[0], finfo[1])
			endif
		endif
	endif
	return

	let index = 0
	echom lines
	let length = strlen(lines)
	while index < length
		let new_index = match(lines, '\n', index)
		if new_index == -1 
			let new_index = length
		endif
		let len = new_index - index
		let line = strpart(lines,index, len)
		let index = new_index + 1
		if line =~ '^Breakpoint \([0-9]\+\) at 0x.*:'
			let cmd = substitute(line, 
						\ '^Breakpoint \([0-9]\+\) at 0x.*: file \([^,]\+\), line \([0-9]\+\).*', 
						\ 's:Gdb_Bpt(\1,"\2",\3)', '')
		elseif line =~ '^Deleted breakpoint \([0-9]\+\)'
			let cmd = substitute(line, '^Deleted breakpoint \([0-9]\+\).*', 's:Gdb_NoBpt(\1)', '')
		elseif line =~ "^\032\032" . '[^:]*\:[0-9]\+'
			let cmd = substitute(line, "^\032\032" . '\([^:]*\):\([0-9]\+\).*', 's:Gdb_CurrFileLine("\1", \2)', '')
		elseif line =~ '^The program is running\.  Exit anyway'
			let cmd = 's:Gdb_interf_close()'
		else
			if (!(line =~ '^(gdb)')) && (! (line =~ '^\s*$'))
				let output_{out_count} = line
				let out_count = out_count + 1
			endif
			continue
		endif
		exec 'call ' . cmd
	endwhile

	if out_count > 0 && s:vimgdb_running
		if(gdb_win != -1)
			if(gdb_win != cur_win)
				exec gdb_win . 'wincmd w'
			endif

			if getline("$") =~ '^\s*$'
				$delete
			endif
			let index = 0
			while index < out_count
				call append(line("$"), output_{index})
				let index = index + 1
			endwhile
			$
			call winline()
			if cur_win != winnr()
				exec cur_win . 'wincmd w'
			endif
		endif
	endif

	if gdb_win == winnr()
		call s:EnterGdbBuf()
	endif

endfun

" Toggle breakpoints
function s:Gdb_togglebreak(name, line)
	let found = 0
	let bcount = 0

	while  bcount <= s:max_break_point
		if exists("s:BptList_".bcount."_file")
			if bufnr(s:BptList_{bcount}_file) == bufnr(a:name) && s:BptList_{bcount}_line == a:line
				let found = 1
				break
			endif
		endif
		let bcount = bcount + 1
	endwhile

	if found == 1
		exec "silent! HightlightOff"
		call s:Gdb_command("clear ".a:name.":".a:line)
	else
		exec "silent! HightlightOn"
		call s:Gdb_command("break ".a:name.":".a:line)
	endif
endfun

function s:Gdb_refresh_window(name)
	let src = 0
	let currentWinNr = winnr()
	for nr in range(1, winnr('$'))
		silent exec nr . "wincmd w"

		let fname = bufname(winbufnr(0))
		if match(fname, a:name) > -1
			silent e!
		endif
	endfor
	silent exec currentWinNr . 'wincmd w'
endfun

function s:Gdb_refresh_source(name, line)
	let src = 0
	let currentWinNr = winnr()
	let gdb_dir = exists("g:tmux_gdb_dir")
	for nr in range(1, winnr('$'))
		silent exec nr . "wincmd w"

		let fname = bufname(winbufnr(0))
		if gdb_dir && match(fname, g:tmux_gdb_dir) > -1
		elseif src == 0
			let src = nr
			silent exec "e! +".a:line." ".a:name
			set cursorline
		endif
	endfor
	silent exec currentWinNr . 'wincmd w'
endfun

" Refresh files
function s:Gdb_refresh_all(name, line)
	let src = 0
	let currentWinNr = winnr()
	let gdb_dir = exists("g:tmux_gdb_dir")
	for nr in range(1, winnr('$'))
		silent exec nr . "wincmd w"
		"set nomodifiable

		let fname = bufname(winbufnr(0))
		if gdb_dir && match(fname, g:tmux_gdb_dir) > -1
			silent e!
			set nocursorline
		elseif src == 0
			let src = nr
			silent exec "e! +".a:line." ".a:name
			set cursorline
		endif
	endfor
	silent exec currentWinNr . 'wincmd w'

	if filereadable(s:gdb_buf_stack)
		exec "cgetfile " . s:gdb_buf_stack
	endif

	"execute "norm mP"
	"let new_list = getqflist()
	"for i in range(len(new_list))
	"	if has_key(new_list[i], 'bufnr')
	"		let new_list[i].filename = fnamemodify(bufname(new_list[i].bufnr), ':p:.')
	"	else
	"		let new_list[i].filename = fnamemodify(new_list[i].filename, ':p:.')
	"	endif
	"	silent! cnext
	"endfor
	"call setqflist(new_list, 'r')
	"execute "norm `P"

	"if filereadable(s:gdb_buf_breakpoints)
	"	exec "lgetfile " . s:gdb_buf_breakpoints
	"endif
endfun

function s:GdbMode_complete(A, L, P)
	return "1.4 GDB.SOURCE /tmp/gdb/"
endfunction

function s:Gdb_shortcuts()
	nmap <silent> <F12>	 :call <SID>Gdb_togglebreak(bufname("%"), line("."))<CR>

	nmap <silent> <F4>	 :call <SID>Gdb_command("print <C-R><C-W>")<CR>
	vmap <silent> <F4>	 "vy:call <SID>Gdb_command("print <C-R>v")<CR>

	nmap <silent> <F2>	 :call <SID>Gdb_command("up")<CR>
	nmap <silent> <F3>	 :call <SID>Gdb_command("down")<CR>

	nmap <silent> <F5>	 :call <SID>Gdb_command("next")<CR>
	nmap <silent> <F6>	 :call <SID>Gdb_command("step")<CR>
	nmap <silent> <F7>	 :call <SID>Gdb_command("finish")<CR>
	nmap <silent> <F8>	 :call <SID>Gdb_command("until")<CR>

	nmap <silent> <F9>	 :call <SID>Gdb_command("continue")<CR>
	nmap <silent> <F10>	 :call <SID>Gdb_command("run")<CR>
endfunction

command! -nargs=* -complete=custom,<SID>GdbMode_complete GdbMode call <SID>Gdb_interf_init(<f-args>)
command! -nargs=* GdbAttach call <SID>Gdb_attach(<f-args>)
command! -nargs=* GdbRefresh call <SID>Gdb_refresh_all(<f-args>)
"nmap <silent> <F2> 	 :GdbMode<CR>
