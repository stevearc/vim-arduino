if (exists('g:loaded_arduino_autoload') && g:loaded_arduino_autoload)
	finish
endif
let g:loaded_arduino_autoload = 1

" Initialization {{{1
" Set up all user configuration variables
function! arduino#InitializeConfig()
  if !exists('g:arduino_board')
    if exists('g:_cache_arduino_board')
      let g:arduino_board = g:_cache_arduino_board
    else
      let g:arduino_board = 'arduino:avr:uno'
    endif
  endif
  if !exists('g:arduino_args')
    let g:arduino_args = '--verbose-upload'
  endif
  if !exists('g:arduino_serial_cmd')
    let g:arduino_serial_cmd = 'screen {port} {baud}'
  endif
  if !exists('g:arduino_serial_baud')
    let g:arduino_serial_baud = 9600
  endif
  if !exists('g:arduino_auto_baud')
    let g:arduino_auto_baud = 1
  endif
  if !exists('g:arduino_serial_tmux')
    let g:arduino_serial_tmux = 'split-window -d'
  endif

  if !exists('g:arduino_serial_port_globs')
    let g:arduino_serial_port_globs = ['/dev/ttyACM*',
                                      \'/dev/ttyUSB*',
                                      \'/dev/tty.usbmodem*',
                                      \'/dev/tty.usbserial*']
  endif
endfunction

" Caching {{{1
" Load the saved defaults
function! arduino#LoadCache()
  let s:cache_dir = exists('$XDG_CACHE_HOME') ? $XDG_CACHE_HOME : $HOME . '/.cache'
  let s:cache = s:cache_dir . '/arduino_cache.vim'
  if s:FileExists(s:cache)
    exec "source " . s:cache
  endif
endfunction

" Save settings to a source-able cache file
function! arduino#SaveCache()
  if !s:FileExists(s:cache_dir)
    call mkdir(s:cache_dir, 'p')
  endif
  let lines = []
  call s:CacheLine(lines, 'g:_cache_arduino_board', g:_cache_arduino_board)
  call writefile(lines, s:cache)
endfunction

" Arduino command helpers {{{1
function! arduino#GetArduinoCommand(cmd)
  let cmd = a:cmd . " --board " . g:arduino_board
  if exists('g:arduino_serial_port')
    let cmd = cmd . " --port " . g:arduino_serial_port
  endif
  let cmd = cmd . " " . g:arduino_args . " " . expand('%:h')
  return cmd
endfunction

function! arduino#GetBoards()
  let arduino_cmd = substitute(system('which arduino'), "\n*$", '', '')
  let arduino_cmd = resolve(arduino_cmd)
  let arduino_dir = fnamemodify(arduino_cmd, ':h')
  let cmd = "find ". arduino_dir . "/hardware -name 'boards.txt' | "
  let cmd = cmd . "xargs grep '^.*\.name' | "
  let cmd = cmd . "sed 's|.*/\\([^/]*\\)/\\([^/]*\\)/boards.txt:\\([^\.]*\\).*|\\1:\\2:\\3|' | "
  let cmd = cmd . "sort -u"
  return split(system(cmd))
endfunction

function! arduino#RebuildMakePrg()
  let &l:makeprg = arduino#GetArduinoCommand("arduino --verify")
endfunction

function! arduino#GetArduinoCommand(cmd)
  let cmd = a:cmd . " --board " . g:arduino_board
  if exists('g:arduino_serial_port')
    let cmd = cmd . " --port " . g:arduino_serial_port
  endif
  let cmd = cmd . " " . g:arduino_args . " " . expand('%')
  return cmd
endfunction

function! s:BoardOrder(b1, b2)
  let c1 = split(a:b1, ':')[2]
  let c2 = split(a:b2, ':')[2]
  return c1 == c2 ? 0 : c1 > c2 ? 1 : -1
endfunction

" Command functions {{{2

" Set the active board
function! arduino#SetBoard(board)
  let g:arduino_board = a:board
  let g:_cache_arduino_board = a:board
  call arduino#RebuildMakePrg()
  call arduino#SaveCache()
endfunction

" Display a list of boards to the user and allow them to choose the active one
function! arduino#ChooseBoard()
  if g:arduino_ctrlp_enabled
    call ctrlp#init(arduino#ctrlp_id())
  else
    let boards = arduino#GetBoards()
    call sort(boards, 's:BoardOrder')
    let labels = ["   Select Arduino Board"]
    let idx = 1
    for board in boards
      call add(labels, idx . ") " . board)
      let idx += 1
    endfor
    let choice = inputlist(labels)
    if choice <= 0
      return
    endif
    call arduino#SetBoard(boards[choice - 1])
  endif
endfunction

function! arduino#Verify()
  let cmd = arduino#GetArduinoCommand("arduino --verify")
  exe ":!" . cmd
  redraw!
  return v:shell_error
endfunction

function! arduino#Upload()
  let cmd = arduino#GetArduinoCommand("arduino --upload")
  exe ":silent !" . cmd
  redraw!
  return v:shell_error
endfunction

function! arduino#Serial()
  let cmd = arduino#GetSerialCmd()
  if !cmd | return | endif
  if !empty($TMUX) && !empty(g:arduino_serial_tmux)
    exe ":silent !tmux " . g:arduino_serial_tmux . " '" . cmd . "'"
  else
    exe ":silent !" . cmd
  endif
  redraw!
endfunction

function! arduino#UploadAndSerial()
  let ret = s:ArduinoUpload()
  if ret == 0
    call s:ArduinoSerial()
  endif
endfunction

" Serial helpers {{{2
function! arduino#GetSerialCmd()
  if exists('g:arduino_serial_port')
    let s:port = g:arduino_serial_port
  else
    let s:port = arduino#GuessSerialPort()
  endif
  if empty(s:port)
    echoerr "Error! No serial port found"
    return
  endif
  let l:cmd = substitute(g:arduino_serial_cmd, '{port}', s:port, 'g')
  let l:cmd = substitute(l:cmd, '{baud}', g:arduino_serial_baud, 'g')
  return l:cmd
endfunction

function! arduino#SetAutoBaud()
  let n = 1
  while n < line("$")
    let match = matchlist(getline(n), 'Serial[0-9]*\.begin(\([0-9]*\)')
    if len(match) >= 2
      let g:arduino_serial_baud = match[1]
      return
    endif
    let n = n + 1
  endwhile
endfunction

function! arduino#GuessSerialPort()
  for l:glob in g:arduino_serial_port_globs
    let ports = glob(l:glob, 1, 1)
    if len(ports)
      return ports[0]
    endif
  endfor
endfunction
"}}}2

" Utility functions {{{1

function! s:FileExists(path)
  return !empty(glob(a:path))
endfunction

function! s:CacheLine(lines, varname, value)
  if exists(a:varname)
    call add(a:lines, 'let ' . a:varname . ' = "' . a:value . '"')
  endif
endfunction

" Ctrlp extension {{{1
if exists('g:ctrlp_ext_vars')
  call add(g:ctrlp_ext_vars, {
    \ 'init': 'arduino#GetBoards()',
    \ 'accept': 'arduino#ctrlp_ChooseBoard',
    \ 'lname': 'long statusline name',
    \ 'sname': 'shortname',
    \ 'type': 'line',
    \ })
  let g:arduino_ctrlp_enabled = 1

  let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
  function! arduino#ctrlp_id()
    return s:id
  endfunction
else
  let g:arduino_ctrlp_enabled = 0
endif

function! arduino#ctrlp_ChooseBoard(mode, str)
	call ctrlp#exit()
  call arduino#SetBoard(a:str)
endfunction

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1
