if exists("g:loaded_vimux") || &cp
  finish
endif
let g:loaded_vimux = 1

" Env Check {{{1
if empty($TMUX)
  finish
endif

if 1 != vimux#_VimuxTmuxOption("pane-base-index", 0)
  echo "Vimux suggest tmux config: setw -g pane-base-index 1"
endif

command! -nargs=1 -complete=custom,vimux#TmuxAttachLists VimuxAttach :call vimux#TmuxAttach(<f-args>)
command -nargs=* Vcmd :call vimux#Run(<args>)
command -nargs=* VimuxRunCommand :call vimux#Run(<args>)
command VimuxRunLastCommand :call vimux#VimuxRunLastCommand()
command VimuxCloseRunner :call vimux#VimuxCloseRunner()
command VimuxZoomRunner :call vimux#VimuxZoomRunner()
command VimuxInspectRunner :call vimux#VimuxInspectRunner()
command VimuxScrollUpInspect :call vimux#VimuxScrollUpInspect()
command VimuxScrollDownInspect :call vimux#VimuxScrollDownInspect()
command VimuxInterruptRunner :call vimux#VimuxInterruptRunner()
command -nargs=? VimuxPromptCommand :call vimux#VimuxPromptCommand(<args>)
command VimuxClearRunnerHistory :call vimux#VimuxClearRunnerHistory()
command VimuxTogglePane :call vimux#VimuxTogglePane()

" Global Vars {{{1
let g:VimuxGroupInit = "init"
let g:VimuxGroupMaxLines = 100
let g:VimuxGroupCommandPause = 50
let g:VimuxGroupCaptureWait = 100
let g:VimuxGroupCaptureLine = 4
" If clear vim command line, use 'q C-u'
let g:VimuxResetSequence = "C-l"

