if (exists('g:loaded_arduino_autoload') && g:loaded_arduino_autoload)
	finish
endif
let g:loaded_arduino_autoload = 1
if has('win64') || has('win32') || has('win16')
  echo "vim-arduino does not support windows :("
  finish
endif
let s:HERE = resolve(expand('<sfile>:p:h:h'))
let s:OS = substitute(system('uname'), '\n', '', '')
" In neovim, run the shell commands using :terminal to preserve interactivity
if has('nvim')
  let s:TERM = 'terminal! '
else
  let s:TERM = '!'
endif

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
  if !exists('g:arduino_programmer')
    if exists('g:_cache_arduino_programmer')
      let g:arduino_programmer = g:_cache_arduino_programmer
    else
      let g:arduino_programmer = 'arduino:usbtinyisp'
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
  if !exists('g:arduino_run_headless')
    let xvfbPath = substitute(system('command -v Xvfb'), "\n*$", '', '')
    let g:arduino_run_headless = empty(xvfbPath) ? 0 : 1
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
  call s:CacheLine(lines, 'g:_cache_arduino_board')
  call s:CacheLine(lines, 'g:_cache_arduino_programmer')
  call writefile(lines, s:cache)
endfunction

" Arduino command helpers {{{1
function! arduino#GetArduinoExecutable()
  if exists('g:arduino_cmd')
    return g:arduino_cmd
  elseif s:OS == 'Darwin'
    return '/Applications/Arduino.app/Contents/MacOS/Arduino'
  else
    return 'arduino'
  endif
endfunction

function! arduino#GetArduinoCommand(cmd)
  let arduino = arduino#GetArduinoExecutable()

  if g:arduino_run_headless
    let arduino = s:HERE . '/bin/run-headless ' . arduino
  endif

  let cmd = arduino . ' ' . a:cmd . " --board " . g:arduino_board
  let port = arduino#GetPort()
  if !empty(port)
    let cmd = cmd . " --port " . port
  endif
  if !empty(g:arduino_programmer)
    let cmd = cmd . " --pref programmer=" . g:arduino_programmer
  endif
  let cmd = cmd . " " . g:arduino_args . " " . expand('%')
  return cmd
endfunction

function! arduino#GetBoards()
  let arduino_dir = arduino#GetArduinoDir()
  let boards = []
  for filename in split(globpath(arduino_dir . '/hardware', '**/boards.txt'), '\n')
    let pieces = split(filename, '/')
    let package = pieces[-3]
    let arch = pieces[-2]
    let lines = readfile(filename)
    for line in lines
      if line =~? '^[^.]*\.build\.board=.*$'
        let linesplit = split(line, '\.')
        let board = linesplit[0]
        call add(boards, package . ':' . arch . ':' . board)
      endif
    endfor
  endfor
  return boards
endfunction

function! arduino#GetBoardOptions(board)
  let arduino_dir = arduino#GetArduinoDir()
  let board_pieces = split(a:board, ':')
  let filename = arduino_dir . '/hardware/' . board_pieces[0] .
        \        '/' . board_pieces[1] . '/boards.txt'
  let lines = readfile(filename)
  let pattern = '^' . board_pieces[2] . '\.menu\.\([^.]*\)\.\([^.]*\)='
  let options = {}
  for line in lines
    if line =~? pattern
      let groups = matchlist(line, pattern)
      let option = groups[1]
      let value = groups[2]
      if !has_key(options, option)
        exec 'let options.' . option . ' = []'
      endif
      let optlist = get(options, option)
      call add(optlist, value)
    endif
  endfor
  return options
endfunction

function! arduino#GetProgrammers()
  let arduino_dir = arduino#GetArduinoDir()
  let programmers = []
  for filename in split(globpath(arduino_dir . '/hardware', '**/programmers.txt'), '\n')
    let pieces = split(filename, '/')
    let package = pieces[-3]
    let lines = readfile(filename)
    for line in lines
      if line =~? '^[^.]*\.name=.*$'
        let linesplit = split(line, '\.')
        let programmer = linesplit[0]
        call add(programmers, package . ':' . programmer)
      endif
    endfor
  endfor
  return sort(programmers)
endfunction

function! arduino#RebuildMakePrg()
  let &l:makeprg = arduino#GetArduinoCommand("--verify")
endfunction

function! s:BoardOrder(b1, b2)
  let c1 = split(a:b1, ':')[2]
  let c2 = split(a:b2, ':')[2]
  return c1 == c2 ? 0 : c1 > c2 ? 1 : -1
endfunction

" Port selection {{{2

function! arduino#ChoosePort(...)
  if a:0
    let g:arduino_serial_port = a:1
    return
  endif
  let ports = arduino#GetPorts()
  if empty(ports)
    echoerr "No likely serial ports detected!"
  else
    call arduino#Choose('Port', ports, 'arduino#SelectPort')
  endif
endfunction

function! arduino#SelectPort(port)
  let g:arduino_serial_port = a:port
endfunction

" Board selection {{{2

let s:callback_data = {}

" Display a list of boards to the user and allow them to choose the active one
function! arduino#ChooseBoard(...)
  if a:0
    call arduino#SetBoard(a:1)
    return
  endif
  let boards = arduino#GetBoards()
  call sort(boards, 's:BoardOrder')
  call arduino#Choose('Arduino Board', boards, 'arduino#SelectBoard')
endfunction

" Callback from board selection. Sets the board and prompts for any options
function! arduino#SelectBoard(board)
  let options = arduino#GetBoardOptions(a:board)
  call arduino#SetBoard(a:board)
  let s:callback_data = {
        \ 'board': a:board,
        \ 'available_opts': options,
        \ 'opts': {},
        \ 'active_option': '',
        \}
  call arduino#ChooseBoardOption()
endfunction

" Prompt user for the next unselected board option
function! arduino#ChooseBoardOption()
  let available_opts = s:callback_data.available_opts
  for opt in keys(available_opts)
    if !has_key(s:callback_data.opts, opt)
      let s:callback_data.active_option = opt
      call arduino#Choose(opt, available_opts[opt], 'arduino#SelectOption')
      return
    endif
  endfor
endfunction

" Callback from option selection
function! arduino#SelectOption(value)
  let opt = s:callback_data.active_option
  let s:callback_data.opts[opt] = a:value
  call arduino#SetBoard(s:callback_data.board, s:callback_data.opts)
  call arduino#ChooseBoardOption()
endfunction

" Programmer selection {{{2

function! arduino#ChooseProgrammer(...)
  if a:0
    call arduino#SetProgrammer(a:1)
    return
  endif
  let programmers = arduino#GetProgrammers()
  call arduino#Choose('Arduino Programmer', programmers, 'arduino#SetProgrammer')
endfunction

function! arduino#SetProgrammer(programmer)
  let g:_cache_arduino_programmer = a:programmer
  let g:arduino_programmer = a:programmer
  call arduino#RebuildMakePrg()
  call arduino#SaveCache()
endfunction

" Command functions {{{2

" Set the active board
function! arduino#SetBoard(board, ...)
  let board = a:board
  if a:0
    let options = a:1
    let prevchar = ':'
    for key in keys(options)
      let board = board . prevchar . key . '=' . options[key]
      let prevchar = ','
    endfor
  endif
  let g:arduino_board = board
  let g:_cache_arduino_board = board
  call arduino#RebuildMakePrg()
  call arduino#SaveCache()
endfunction

function! arduino#Verify()
  let cmd = arduino#GetArduinoCommand("--verify")
  exe ":silent !echo " . cmd
  exe ":" . s:TERM . cmd
  redraw!
  return v:shell_error
endfunction

function! arduino#Upload()
  let cmd = arduino#GetArduinoCommand("--upload")
  exe ":silent !echo " . cmd
  exe ":silent " . s:TERM . cmd
  redraw!
  return v:shell_error
endfunction

function! arduino#Serial()
  let cmd = arduino#GetSerialCmd()
  if empty(cmd) | return | endif
  exe ":silent !echo " . cmd
  if !empty($TMUX) && !empty(g:arduino_serial_tmux)
    exe ":" . s:TERM . "tmux " . g:arduino_serial_tmux . " '" . cmd . "'"
  else
    exe ":" . s:TERM . cmd
  endif
  redraw!
endfunction

function! arduino#UploadAndSerial()
  let ret = arduino#Upload()
  if ret == 0
    call arduino#Serial()
  endif
endfunction

" Serial helpers {{{2

function! arduino#GetSerialCmd()
  let port = arduino#GetPort()
  if empty(port)
    echoerr "Error! No serial port found"
    return ''
  endif
  let l:cmd = substitute(g:arduino_serial_cmd, '{port}', port, 'g')
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

function! arduino#GetPorts()
  let ports = []
  for l:glob in g:arduino_serial_port_globs
    let found = glob(l:glob, 1, 1)
    for port in found
      call add(ports, port)
    endfor
  endfor
  return ports
endfunction

function! arduino#GuessSerialPort()
  let ports = arduino#GetPorts()
  if empty(ports)
    return 0
  else
    return ports[0]
  endif
endfunction

function! arduino#GetPort()
  if exists('g:arduino_serial_port')
    return g:arduino_serial_port
  else
    return arduino#GuessSerialPort()
  endif
endfunction

"}}}2

" Utility functions {{{1

function! arduino#Choose(title, items, callback)
  if g:arduino_ctrlp_enabled
    let ext_data = get(g:ctrlp_ext_vars, s:ctrlp_idx)
    let ext_data.lname = a:title
    let s:ctrlp_list = a:items
    let s:ctrlp_callback = a:callback
    call ctrlp#init(s:ctrlp_id)
  else
    let labels = ["   " . a:title]
    let idx = 1
    for item in a:items
      call add(labels, idx . ") " . item)
      let idx += 1
    endfor
    let choice = inputlist(labels)
    if choice > 0
      call call(a:callback, [a:items[choice-1]])
    endif
  endif
endfunction

function! arduino#FindExecutable(name)
  let path = substitute(system('command -v ' . a:name), "\n*$", '', '')
  if empty(path) | return 0 | endif
  let abspath = resolve(path)
  return abspath
endfunction

function! s:FileExists(path)
  return !empty(glob(a:path))
endfunction

function! s:CacheLine(lines, varname)
  if exists(a:varname)
    let value = eval(a:varname)
    call add(a:lines, 'let ' . a:varname . ' = "' . value . '"')
  endif
endfunction

function! arduino#GetArduinoDir()
  if exists('g:arduino_dir')
    return g:arduino_dir
  endif
  let executable = arduino#GetArduinoExecutable()
  let arduino_cmd = arduino#FindExecutable(executable)
  let arduino_dir = fnamemodify(arduino_cmd, ':h')
  if s:OS == 'Darwin'
    let arduino_dir = fnamemodify(arduino_dir, ':h') . '/Java'
  endif
  if !s:FileExists(arduino_dir . '/hardware/arduino/')
    throw "Could not find arduino directory. Please set g:arduino_dir"
  endif
  return arduino_dir
endfunction

" Ctrlp extension {{{1
if exists('g:ctrlp_ext_vars')
  let g:arduino_ctrlp_enabled = 1
  let s:ctrlp_idx = len(g:ctrlp_ext_vars)
  call add(g:ctrlp_ext_vars, {
    \ 'init': 'arduino#ctrlp_GetData()',
    \ 'accept': 'arduino#ctrlp_Callback',
    \ 'lname': 'arduino',
    \ 'sname': 'arduino',
    \ 'type': 'line',
    \ })

  let s:ctrlp_id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
else
  let g:arduino_ctrlp_enabled = 0
endif

function! arduino#ctrlp_GetData()
  return s:ctrlp_list
endfunction

function! arduino#ctrlp_Callback(mode, str)
	call ctrlp#exit()
  call call(s:ctrlp_callback, [a:str])
endfunction

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1
