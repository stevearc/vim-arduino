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
    let g:arduino_args = '--verbose'
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

" Load the saved defaults
function! arduino#LoadCache()
  let s:cache_dir = exists('$XDG_CACHE_HOME') ? $XDG_CACHE_HOME : $HOME . '/.cache'
  let s:cache = s:cache_dir . '/arduino_cache.vim'
  if s:fileExists(s:cache)
    exec "source " . s:cache
  endif
endfunction

" Save settings to a source-able cache file
function! arduino#SaveCache()
  if !s:fileExists(s:cache_dir)
    call mkdir(s:cache_dir, 'p')
  endif
  let lines = []
  call s:cacheLine(lines, 'g:_cache_arduino_board', g:_cache_arduino_board)
  call writefile(lines, s:cache)
endfunction

function! arduino#GetArduinoCommand(cmd)
  let cmd = a:cmd . " --board " . g:arduino_board
  if exists('g:arduino_serial_port')
    let cmd = cmd . " --port " . g:arduino_serial_port
  endif
  let cmd = cmd . " " . g:arduino_args . " " . expand('%:h')
  return cmd
endfunction

function! arduino#RebuildMakePrg()
  let &l:makeprg = arduino#GetArduinoCommand("arduino --verify")
endfunction

" Utility functions

function! s:fileExists(path)
  return !empty(glob(a:path))
endfunction

function! s:cacheLine(lines, varname, value)
  if exists(a:varname)
    call add(a:lines, 'let ' . a:varname . ' = "' . a:value . '"')
  endif
endfunction
