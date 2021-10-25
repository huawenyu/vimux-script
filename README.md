# vimux-script

Vim + Tmux + the-plug: use vim as tmux controller, and vimux-script language interact with tmux from vim.
This plugin is base on [vimux](https://github.com/benmills/vimux), a plugin that lets you send input to tmux.

The vim plug is to make auto interact with terminal through tmux.

## Quickstart

Put the cursor in the region of script, which begin-with `{{{#` and end-with `}}}` like the sample,
then `:call vimuxscript#CallRegion(1)`.
For example, simulate top:

```sh
top {{{1
    ## Put cursor in this region, then :call vimuxscript#CallRegion(1)
    ##
    ## comment by beginwith two '##'
    ## Inner command begeinwith '@'
    ## @attach  Interact with tmux current window pane 2, like: @attach [<window>.]pane
    ##          2.3    the tmux window-2, pane-3
    @attach 2

	@vimbegin
	let w:num = 1
	while w:num <= 20
		let w:num = w:num + 1
		call VimSend('top -bn1 | head')
        sleep 1
	endwhile
	@vimend
}}}
```

```sh
getstatus {{{1
    @attach 2
    telnet 10.1.1.125

    ## user:admin, and password is empty
    admin
    <Enter>

    ## the embedded box's command
    ## ls -lart
    get system status
}}}
```

## Install

- Install this vim plug
```vim
    " With **[vim-plug](https://github.com/junegunn/vim-plug)**, add to your `.vimrc`:
    Plug 'huawenyu/vimux-script'
```
- Only worker under tmux (version > 1.5)
  > Auto send the script text to tmux another pane`

## Usage

The more example is available [online](https://raw.github.com/huawenyu/vimux-script/master/example.txt).
### Prerequirement
Firstly, we should use tmux to get 4 panes in current terminal screen. So we have pane number 1,2,3,4,  
If together with the windows number, we have pane like: 1.1, 1.2, 1.3, 1.4

### Execute The Selected Lines

1. use vim open a text file
2. attach current vim to another tmux's pane by the pane's number
```
       :VimuxAttach <tab>
```

### Sample to decode gdb call backtrace

We have a calltrace file `calltrace.txt` and the bin file `a.out`, and want to send gdb to decode the the backtrace automatically.

1. Open tmux window, then create two panes:
   the 1st pane: vim calltrace.txt
   the 2nd pane: gdb a.out

2. Using @begin, @end to define the script region
Setting it in the default `init` group, like:
```python
init {{{1
@begin Call Trace:
@end Detaching from target
}}}
```

3. Change `[<00007f2f035a89d7>]` to `l *0x00007f2f035a89d7`
Add a match-then-do-macro to change the script text line to the default `init` group:

```python
init {{{1
@match "^[" => "0xx$xx0il *0x"
}}}
```

4. Finally our text script like this:

    $ cat ./calltrace.txt

```python
init {{{1
@begin Call Trace:
@end Detaching from target
@begin_cmd #----------------------------------
@end_cmd   #==================================
@match "^[" => "0xx$xx0il *0x"
}}}

Attaching to the target process...
Waiting for target process to stop...
Target process attached
Register dump:
Pid: 6432
rip: 0033:[<00007f2f035a89d7>]
rsp: 002b:00007fffece6d468  eflags: 00000246
rax: 0000000000000000 rbx: 0000000000001000 rcx: ffffffffffffffff
rdx: 0000000000000ff4 rsi: 0000000000001000 rdi: 00007f2e8a506000
rbp: 00007fffece6d490 r08: 00007f2f05370e30 r09: 0000000000000000
r10: 00007fffece6d4ac r11: 0000000000000246 r12: 00007f2e8a506000
r13: 0000000000000000 r14: 0000000000000000 r15: 00007f2e8b675688
Call Trace:
[<00007f2f035a89d7>]
[<00000000017da808>]
[<00000000018f1194>]
[<00000000018fbf36>]
[<00000000018f5ccc>]
[<000000000175114f>]
[<00000000018f5e3a>]
[<00000000018f8369>]
[<000000000188022a>]
[<000000000190d6a6>]
[<0000000000448b18>]
[<000000000044f4f1>]
[<00007f2f034d9eaa>]
[<0000000000444e5a>]
Detaching from target...
Target detached
```

5. Put our cursor beteween the `Call Trace` and `Detaching from target`,
   then `:call vimuxscript#CallRegion(1)`


### Execute Group By Name

1. use vim open a script like this which must begin-with `{{{#` and end-with `}}}`:
```
init {{{1
	@vim let w:pane_log = '1.4'
	@vim let w:pane_box = '1.3'
	@vim let w:pane_gdb = '1.4'
}}}

readcrash {{{1
	@label check_crash_again

	@attach $<w:pane_box>
	diagnose ourapp  3130

	@attach $<w:pane_gdb>
	curl -4 -x 10.1.100.150:8080 www.tired.com

	@attach $<w:pane_log>
	diagnose crash get

	@goto check_crash_again
}}}
```
2. In vim, put our cusor on `decode_debug_acsm_crash` which is the script group's name
3. Then :call vimuxscript#ExecuteGroup()
4. If the script have variable like `$<w:pane_box>`, it will auto search the `init` group.

### vim Shortkeys
```
  vmap <silent> <leader>ee  :<c-u>call vimuxscript#ExecuteSelection(1)<CR>
  nmap <silent> <leader>ee  :<c-u>call vimuxscript#ExecuteSelection(0)<CR>
  nmap <silent> <leader>eg  :<c-u>call vimuxscript#ExecuteGroup()<CR>
```

## Debug
let let g:decho_enable = 1

## Todo lists

- [x] Attach tmux.windows mode
- [x] Auto 'init' per script files
- [ ] Add <file>
- [ ] Script: decode crash log
- [ ] AsyncCommand Implement
  - [ ] grep
  - [ ] make

