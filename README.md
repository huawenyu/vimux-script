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
  3. In vim, visual select serveral lines which we want send them to the destination pane
  4. if have selected lines,    :call vimuxscript#ExecuteSelection(1)
  5. if only send current line, :call vimuxscript#ExecuteSelection(0)

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

