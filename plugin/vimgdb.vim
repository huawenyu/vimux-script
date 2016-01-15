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
let s:vimgdb_running = 0
let s:gdb_win_hight = 2
let s:gdb_output_width = 10

let s:gdb_buf_name = "__GDB_WINDOW__"
let s:gdb_buf_registers = "__GDB_REG__"
let s:gdb_buf_source = "__GDB_SRC__"
let s:gdb_buf_assembly = "__GDB_ASM__"
let s:gdb_buf_stack = "__GDB_STACK__"
let s:gdb_buf_thread = "__GDB_THR__"
let s:gdb_buf_output = "__GDB_OUTPUT__"

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

" Get ready for communication
function! s:Gdb_interf_init()

	call s:Gdb_shortcuts()

	"command -nargs=+ Gdb	:call Gdb_command(<q-args>, v:count)
	"call s:Gdb_buf_split(s:gdb_buf_name, s:gdb_win_hight, "botright")
	"call s:Gdb_buf_split(s:gdb_buf_output, s:gdb_output_width, "topright")

    " Mark the buffer as a scratch buffer
    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal noswapfile
    setlocal wrap
    setlocal nobuflisted
    setlocal nonumber

    augroup VimGdbAutoCommand
		autocmd WinEnter <buffer> call s:EnterGdbBuf()
		autocmd WinLeave <buffer> stopi
    augroup end

	hi CursorLine cterm=NONE ctermbg=darkred ctermfg=white
	set cursorline

    "inoremap <buffer> <silent> <CR> <ESC>o<ESC>:call <SID>Gdb_command(getline(line(".")-1))<CR>
	"inoremap <buffer> <silent> <TAB> <C-P>
	"nnoremap <buffer> <silent> : <C-W>p:

	start
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

	if exists("g:tmux_gdb")
		"let hist_pos = vimuxscript#_TmuxInfoRefresh()
		call vimux#TmuxAttach2(g:tmux_gdb)
		call vimux#Run(a:cmd)
		"let lines = vimuxscript#_Capture(hist_pos)
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
		call s:Gdb_command("clear ".a:name.":".a:line)
	else
		call s:Gdb_command("break ".a:name.":".a:line)
	endif
endfun

function s:Gdb_shortcuts()
	nmap <silent> <F12>	 :call <SID>Gdb_togglebreak(bufname("%"), line("."))<CR>

	nmap <silent> <F4>	 :call <SID>Gdb_command("print <C-R><C-W>")<CR>
	vmap <silent> <F4>	 "vy:call <SID>Gdb_command("print <C-R>v")<CR>
	nmap <silent> <F5>	 :call <SID>Gdb_command("next")<CR>
	nmap <silent> <F6>	 :call <SID>Gdb_command("step")<CR>
	nmap <silent> <F7>	 :call <SID>Gdb_command("finish")<CR>
	nmap <silent> <F8>	 :call <SID>Gdb_command("continue")<CR>
	nmap <silent> <F9>	 :call <SID>Gdb_command("run")<CR>
endfunction

command! GdbMode call <SID>Gdb_interf_init()
"nmap <silent> <F2> 	 :GdbMode<CR>
