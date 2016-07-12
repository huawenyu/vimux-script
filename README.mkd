# vimux-script

Vim+Tmux+vimux-script: use vim as tmux controller, and vimux-script language interact with tmux from vim.

This plugin is base on [vimux](https://github.com/benmills/vimux), a plugin that lets you send input to tmux.

My goal with vimux-script is to make scriptable auto interacting with tmux from vim effortless.
By default you can `:call vimuxscript#ExecuteGroupByname('embedded_status')` to execute a function-like script which begin-with `{{{#` and end-with `}}}` :

```
embedded_status {{{1
    " tmux's pane index, show by prefix-q
    " <attach> means send the command to that tmux pane shell
    <attach> 2
    telnet 10.1.1.124

    " user:admin, and password is empty
    admin
    <Enter>

    " the embedded box's command
    get system status
}}}
```

The vimuxscript functions list:  

```
  vimuxscript#Copy
  vimuxscript#ExecuteGroup
  vimuxscript#ExecuteGroupByname
  vimuxscript#ExecuteSelection
  vimuxscript#StartCopy
  vimuxscript#_Capture
  vimuxscript#_Exe
  vimuxscript#_ExecuteCmd
  vimuxscript#_ExecuteInnnerAction
  vimuxscript#_ExecuteOneLine
  vimuxscript#_ExecuteRegion
  vimuxscript#_GetParams
  vimuxscript#_GetRegion
  vimuxscript#_ParseVars
  vimuxscript#_StartInsert
  vimuxscript#_TmuxInfoRefresh
```

## Installation

With **[vim-bundle](https://github.com/benmills/vim-bundle)**: `vim-bundle install huawenyu/vimux-script`
With **[Vundle](https://github.com/gmarik/Vundle.vim)**: 'Plugin huawenyu/vimux-script' in your .vimrc

Otherwise download the latest [tarball](https://github.com/huawenyu/vimux-script/tarball/master), extract it and move `plugin/vimux-script` inside `~/.vim/plugin`. If you're using [pathogen](https://github.com/tpope/vim-pathogen), then move the entire folder extracted from the tarball into `~/.vim/bundle`.

_Notes:_ 

* Vimux assumes a tmux version >= 1.5. Some older versions might work but it is recommeded to use at least version 1.5.

## Usage

The more example is available [online](https://raw.github.com/huawenyu/vimux-script/master/example.txt).
### Prerequirement
Firstly, we should use tmux to get 4 panes in current terminal screen. So we have pane number 1,2,3,4,  
If together with the windows number, we have pane like: 1.1, 1.2, 1.3, 1.4

### Execute The Selected Lines

  1. use vim open a text file
  2. attach current vim to another tmux's pane by the pane's number
```
       :VimuxAttach <TAB>
```
  3. In vim, visual select serveral lines which we want send them to the destination pane
  4. if have selected lines,    :call vimuxscript#ExecuteSelection(1)
  5. if only send current line, :call vimuxscript#ExecuteSelection(0)

### Execute Group By Name

  1. use vim open a script like this which must begin-with `{{{#` and end-with `}}}`:
```
init {{{1
	<let> w:pane_log = '1.4'
	<let> w:pane_box = '1.3'
	<let> w:pane_gdb = '1.4'
}}}

decode_debug_acsm_crash {{{1
	<label> check_crash_again

	<attach> $<w:pane_box>
	diagnose ourapp  3130

	<attach> $<w:pane_gdb>
	curl -4 -x 10.1.100.150:8080 www.tired.com

	<attach> $<w:pane_log>
	diagnose crash get

	<goto> check_crash_again
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

- [ ] Attach tmux.windows mode
- [ ] Auto 'init' per script files
- [ ] Add <file>
- [ ] Script: decode crash log
- [ ] AsyncCommand Implement
  - [ ] grep
  - [ ] make

