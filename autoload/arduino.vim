if (exists('g:loaded_arduino_autoload') && g:loaded_arduino_autoload)
    finish
endif
let g:loaded_arduino_autoload = 1
let s:has_cli = executable('arduino-cli') == 1
if has('win64') || has('win32') || has('win16')
  echoerr "vim-arduino does not support windows :("
  finish
endif
let s:HERE = resolve(expand('<sfile>:p:h:h'))
let s:OS = substitute(system('uname'), '\n', '', '')
" In neovim, run the shell commands using :terminal to preserve interactivity
if has('nvim')
  let s:TERM = 'botright split | terminal! '
elseif has('terminal')
  " In vim, doing terminal! will automatically open in a new split
  let s:TERM = 'terminal! '
else
  " Backwards compatible with old versions of vim
  let s:TERM = '!'
endif
let s:hardware_dirs = {}
python3 import json

" Initialization {{{1
" Set up all user configuration variables
function! arduino#InitializeConfig() abort
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
      let g:arduino_programmer = ''
    endif
  endif
  if !exists('g:arduino_args')
    let g:arduino_args = '--verbose-upload'
  endif
  if !exists('g:arduino_cli_args')
    let g:arduino_cli_args = '-v'
  endif
  if !exists('g:arduino_serial_cmd')
    let g:arduino_serial_cmd = 'screen {port} {baud}'
  endif
  if !exists('g:arduino_build_path')
    let g:arduino_build_path = '{project_dir}/build'
  endif

  if !exists('g:arduino_serial_baud')
    let g:arduino_serial_baud = 9600
  endif
  if !exists('g:arduino_auto_baud')
    let g:arduino_auto_baud = 1
  endif
  if !exists('g:arduino_use_slime')
    let g:arduino_use_slime = 0
  endif

  if !exists('g:arduino_run_headless')
    let g:arduino_run_headless = executable('Xvfb') == 1
  endif

  if !exists('g:arduino_serial_port_globs')
    let g:arduino_serial_port_globs = ['/dev/ttyACM*',
                                      \'/dev/ttyUSB*',
                                      \'/dev/tty.usbmodem*',
                                      \'/dev/tty.usbserial*',
                                      \'/dev/tty.wchusbserial*']
  endif
  if !exists('g:arduino_use_cli')
    let g:arduino_use_cli = s:has_cli
  elseif g:arduino_use_cli && !s:has_cli
    echoerr 'arduino-cli: command not found'
  endif
  call arduino#ReloadBoards()
endfunction

" Boards and programmer definitions {{{1
function! arduino#ReloadBoards() abort
  " TODO in the future if we're using arduino-cli we shouldn't have to do this,
  " but at the moment I'm having issues where `arduino-cli board details
  " adafruit:avr:gemma --list-programmers` is empty

  " First let's search the arduino system install for boards
  " The path looks like /hardware/<package>/<arch>/boards.txt
  let arduino_dir = arduino#GetArduinoDir()
  let filenames = split(globpath(arduino_dir . '/hardware', '**/boards.txt'), '\n')
  for filename in filenames
    let pieces = split(filename, '/')
    let package = pieces[-3]
    let arch = pieces[-2]
    call arduino#AddHardwareDir(package, arch, filename)
  endfor

  " Now search any packages installed in the home dir
  " The path looks like /packages/<package>/hardware/<arch>/<version>/boards.txt
  let arduino_home_dir = arduino#GetArduinoHomeDir()
  let packagedirs = split(globpath(arduino_home_dir . '/packages', '*'), '\n')
  for packagedir in packagedirs
    let package = fnamemodify(packagedir, ':t')
    let archdirs = split(globpath(packagedir . '/hardware', '*'), '\n')
    for archdir in archdirs
      let arch = fnamemodify(archdir, ':t')
      let filenames = split(globpath(archdir, '**/boards.txt'), '\n')
      for filename in filenames
        call arduino#AddHardwareDir(package, arch, filename)
      endfor
    endfor
  endfor

  " Some platforms put the default arduino boards/programmers in /etc/arduino
  if filereadable('/etc/arduino/boards.txt')
    call arduino#AddHardwareDir('arduino', 'avr', '/etc/arduino')
  endif
  if empty(s:hardware_dirs)
    echoerr "Could not find any boards.txt or programmers.txt files. Please set g:arduino_dir and/or g:arduino_home_dir (see help for details)"
  endif
endfunction

function! arduino#AddHardwareDir(package, arch, file) abort
  " If a boards.txt file was passed in, get the parent dir
  if !isdirectory(a:file)
    let filepath = fnamemodify(a:file, ':h')
  else
    let filepath = a:file
  endif
  if !isdirectory(filepath)
    echoerr 'Could not find hardware directory or file '. a:file
    return
  endif
  let s:hardware_dirs[filepath] = {
    \ "package": a:package,
    \ "arch": a:arch,
    \}
endfunction

" Caching {{{1
" Load the saved defaults
function! arduino#LoadCache() abort
  let s:cache_dir = exists('$XDG_CACHE_HOME') ? $XDG_CACHE_HOME : $HOME . '/.cache'
  let s:cache = s:cache_dir . '/arduino_cache.vim'
  if filereadable(s:cache)
    exec "source " . s:cache
  endif
endfunction

" Save settings to a source-able cache file
function! arduino#SaveCache() abort
  if !isdirectory(s:cache_dir)
    call mkdir(s:cache_dir, 'p')
  endif
  let lines = []
  call s:CacheLine(lines, 'g:_cache_arduino_board')
  call s:CacheLine(lines, 'g:_cache_arduino_programmer')
  call writefile(lines, s:cache)
endfunction

" Arduino command helpers {{{1
function! arduino#GetArduinoExecutable() abort
  if exists('g:arduino_cmd')
    return g:arduino_cmd
  elseif s:OS == 'Darwin'
    return '/Applications/Arduino.app/Contents/MacOS/Arduino'
  else
    return 'arduino'
  endif
endfunction

function! arduino#GetBuildPath() abort
  if empty(g:arduino_build_path)
    return ''
  endif
  let l:path = g:arduino_build_path
  let l:path = substitute(l:path, '{file}', expand('%:p'), 'g')
  let l:path = substitute(l:path, '{project_dir}', expand('%:p:h'), 'g')
  return l:path
endfunction

function! arduino#GetCLICompileCommand(...) abort
  let cmd = 'arduino-cli compile -b ' . g:arduino_board
  let port = arduino#GetPort()
  if !empty(port)
    let cmd = cmd . ' -p ' . port
  endif
  if !empty(g:arduino_programmer)
    let cmd = cmd . ' -P ' . g:arduino_programmer
  endif
  let l:build_path = arduino#GetBuildPath()
  if !empty(l:build_path)
    let cmd = cmd . ' --build-path "' . l:build_path . '"'
  endif
  if a:0
    let cmd = cmd . " " . a:1
  endif
  return cmd . " " . g:arduino_cli_args . ' "' . expand('%:p') . '"'
endfunction

function! arduino#GetArduinoCommand(cmd) abort
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
  let l:build_path = arduino#GetBuildPath()
  if !empty(l:build_path)
    let cmd = cmd . " --pref " . '"build.path=' . l:build_path . '"'
  endif
  let cmd = cmd . " " . g:arduino_args . ' "' . expand('%:p') . '"'
  return cmd
endfunction

function! arduino#GetBoards() abort
  let boards = []
  if g:arduino_use_cli
    let boards_data = s:get_json_output('arduino-cli board listall --format json')
    for board in boards_data['boards']
      call add(boards, {
            \ 'label': board['name'],
            \ 'value': board['fqbn']
            \ })
    endfor
  else
    let seen = {}
    for [dir,meta] in items(s:hardware_dirs)
      if !isdirectory(dir)
        continue
      endif
      let filename = dir . '/boards.txt'
      if !filereadable(filename)
        continue
      endif
      let lines = readfile(filename)
      for line in lines
        if line =~? '^[^.]*\.name=.*$'
          let linesplit = split(line, '\.')
          let board = linesplit[0]
          let linesplit = split(line, '=')
          let name = linesplit[1]
          let board = meta.package . ':' . meta.arch . ':' . board
          if !has_key(seen, board)
            let seen[board] = 1
            call add(boards, {
                  \ 'label': name,
                  \ 'value': board
                  \ })
          endif
        endif
      endfor
      unlet dir meta
    endfor
  endif
  call sort(boards, 's:ChooserItemOrder')
  return boards
endfunction

function! arduino#GetBoardOptions(board) abort
  if g:arduino_use_cli
    let ret = []
    let data = s:get_json_output('arduino-cli board details ' . a:board . ' --format json')
    if !has_key(data, 'config_options')
      return ret
    endif
    let opts = data['config_options']
    for opt in opts
      let values = []
      for entry in opt['values']
        call add(values, {
          \ 'label': entry['value_label'],
          \ 'value': entry['value']
          \ })
      endfor
      call add(ret, {
            \ 'option': opt['option'],
            \ 'option_label': opt['option_label'],
            \ 'values': values
            \ })
    endfor
    return ret
  endif

  " Board will be in the format package:arch:board
  let [package, arch, boardname] = split(a:board, ':')

  " Find all boards.txt files with that package/arch
  let boardfiles = []
  for [dir,meta] in items(s:hardware_dirs)
    if meta.package == package && meta.arch == arch
      call add(boardfiles, dir.'/boards.txt')
    endif
    unlet dir meta
  endfor

  " Find the boards.txt file with the board definition and read the options
  for filename in boardfiles
    if !filereadable(filename)
      continue
    endif
    let lines = readfile(filename)
    let pattern = '^' . boardname . '\.menu\.\([^.]*\)\.\([^.]*\)='
    let options = {}
    let matched = 0
    for line in lines
      if line =~? pattern
        let matched = 1
        let groups = matchlist(line, pattern)
        let option = groups[1]
        let value = groups[2]
        if !has_key(options, option)
          let options[option] = []
        endif
        let optlist = get(options, option)
        call add(optlist, value)
      endif
    endfor
    if matched
      let ret = []
      for value in keys(options)
        call add(ret, {
              \ 'option': value,
              \ 'option_label': value,
              \ 'values': options[value]
              \ })
      endfor
      return ret
    endif
  endfor
  return []
endfunction

function! arduino#GetProgrammers() abort
  let programmers = [{
        \ 'label': '-None-',
        \ 'value': '',
        \}]
  if g:arduino_use_cli
    let data = s:get_json_output('arduino-cli board details ' . g:arduino_board . ' --list-programmers --format json')
    if has_key(data, 'programmers')
      for entry in data['programmers']
        call add(programmers, {
              \ 'label': entry['name'],
              \ 'value': entry['id'],
              \ })
      endfor
      " I'm running into some issues with 3rd party boards (e.g. adafruit:avr:gemma) where the programmer list is empty. If so, fall back to the hardware directory method
      if !empty(programmers)
        return sort(programmers, 's:ChooserItemOrder')
      endif
    endif
  endif

  let seen = {}
  for [dir,meta] in items(s:hardware_dirs)
    if !isdirectory(dir)
      continue
    endif
    let filename = dir . '/programmers.txt'
    if !filereadable(filename)
      continue
    endif
    let lines = readfile(filename)
    for line in lines
      if line =~? '^[^.]*\.name=.*$'
        let linesplit = split(line, '\.')
        let programmer = linesplit[0]
        let linesplit = split(line, '=')
        let name = linesplit[1]
        let prog = meta.package . ':' . programmer
        if !has_key(seen, prog)
          let seen[prog] = 1
          call add(programmers, {
                \ 'label': name,
                \ 'value': prog
                \ })
        endif
      endif
    endfor
  endfor
  return sort(programmers)
endfunction

function! arduino#RebuildMakePrg() abort
  if g:arduino_use_cli
    let &l:makeprg = arduino#GetCLICompileCommand()
  else
    let &l:makeprg = arduino#GetArduinoCommand("--verify")
  endif
endfunction

function! s:ChooserItemOrder(i1, i2) abort
  let l1 = has_key(a:i1, 'label') ? a:i1['label'] : a:i1['value']
  let l2 = has_key(a:i2, 'label') ? a:i2['label'] : a:i2['value']
  return l1 == l2 ? 0 : l1 > l2 ? 1 : -1
endfunction

" Port selection {{{2

function! arduino#ChoosePort(...) abort
  if a:0
    let g:arduino_serial_port = a:1
    return
  endif
  let ports = arduino#GetPorts()
  if empty(ports)
    echoerr "No likely serial ports detected!"
  else
    call arduino#chooser#Choose('Select Port', ports, 'arduino#SelectPort')
  endif
endfunction

function! arduino#SelectPort(port) abort
  let g:arduino_serial_port = a:port
endfunction

" Board selection {{{2

let s:callback_data = {}

" Display a list of boards to the user and allow them to choose the active one
function! arduino#ChooseBoard(...) abort
  if a:0
    call arduino#SetBoard(a:1)
    return
  endif
  let boards = arduino#GetBoards()
  call arduino#chooser#Choose('Select Board', boards, 'arduino#SelectBoard')
endfunction

" Callback from board selection. Sets the board and prompts for any options
function! arduino#SelectBoard(board) abort
  let options = arduino#GetBoardOptions(a:board)
  call arduino#SetBoard(a:board)
  let s:callback_data = {
        \ 'board': a:board,
        \ 'available_opts': options,
        \ 'opts': {},
        \ 'active_option': '',
        \}
  " Have to delay this to give the previous chooser UI time to clear
  call timer_start(10, {tid -> arduino#ChooseBoardOption()})
endfunction

" Prompt user for the next unselected board option
function! arduino#ChooseBoardOption() abort
  let available_opts = s:callback_data.available_opts
  for opt in available_opts
    if !has_key(s:callback_data.opts, opt.option)
      let s:callback_data.active_option = opt.option
      call arduino#chooser#Choose(opt.option_label, opt.values, 'arduino#SelectOption')
      return
    endif
  endfor
endfunction

" Callback from option selection
function! arduino#SelectOption(value) abort
  let opt = s:callback_data.active_option
  let s:callback_data.opts[opt] = a:value
  call arduino#SetBoard(s:callback_data.board, s:callback_data.opts)
  call arduino#ChooseBoardOption()
endfunction

" Programmer selection {{{2

function! arduino#ChooseProgrammer(...) abort
  if a:0
    call arduino#SetProgrammer(a:1)
    return
  endif
  let programmers = arduino#GetProgrammers()
  call arduino#chooser#Choose('Select Programmer', programmers, 'arduino#SetProgrammer')
endfunction

function! arduino#SetProgrammer(programmer) abort
  let g:_cache_arduino_programmer = a:programmer
  let g:arduino_programmer = a:programmer
  call arduino#RebuildMakePrg()
  call arduino#SaveCache()
endfunction

" Command functions {{{2

" Set the active board
function! arduino#SetBoard(board, ...) abort
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

function! arduino#Verify() abort
  if g:arduino_use_cli
    let cmd = arduino#GetCLICompileCommand()
  else
    let cmd = arduino#GetArduinoCommand("--verify")
  endif
  if g:arduino_use_slime
    call slime#send(cmd."\r")
  else
    exe s:TERM . cmd
  endif
  return v:shell_error
endfunction

function! arduino#Upload() abort
  if g:arduino_use_cli
    let cmd = arduino#GetCLICompileCommand('-u')
  else
    if empty(g:arduino_programmer)
      let cmd_options = "--upload"
    else
      let cmd_options = "--upload --useprogrammer"
    endif
    let cmd = arduino#GetArduinoCommand(cmd_options)
  endif
  if g:arduino_use_slime
    call slime#send(cmd."\r")
  else
    exe s:TERM . cmd
  endif
  return v:shell_error
endfunction

function! arduino#Serial() abort
  let cmd = arduino#GetSerialCmd()
  if empty(cmd) | return | endif
  if g:arduino_use_slime
    call slime#send(cmd."\r")
  else
    exe s:TERM . cmd
  endif
endfunction

function! arduino#UploadAndSerial() abort
  let ret = arduino#Upload()
  if ret == 0
    call arduino#Serial()
  endif
endfunction

" Serial helpers {{{2

function! arduino#GetSerialCmd() abort
  let port = arduino#GetPort()
  if empty(port)
    echoerr "Error! No serial port found"
    return ''
  endif
  let l:cmd = substitute(g:arduino_serial_cmd, '{port}', port, 'g')
  let l:cmd = substitute(l:cmd, '{baud}', g:arduino_serial_baud, 'g')
  return l:cmd
endfunction

function! arduino#SetBaud(baud) abort
  let g:arduino_serial_baud = a:baud
endfunction

function! arduino#SetAutoBaud() abort
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

function! arduino#GetPorts() abort
  let ports = []
  for l:glob in g:arduino_serial_port_globs
    let found = glob(l:glob, 1, 1)
    for port in found
      call add(ports, port)
    endfor
  endfor
  return ports
endfunction

function! arduino#GuessSerialPort() abort
  let ports = arduino#GetPorts()
  if empty(ports)
    return 0
  else
    return ports[0]
  endif
endfunction

function! arduino#GetPort() abort
  if exists('g:arduino_serial_port')
    return g:arduino_serial_port
  else
    return arduino#GuessSerialPort()
  endif
endfunction

"}}}2

" Utility functions {{{1

function! s:get_json_output(cmd) abort
  let output_str = system(a:cmd)
  return py3eval('json.loads(vim.eval("output_str"))')
endfunction

function! s:CacheLine(lines, varname) abort
  if exists(a:varname)
    let value = eval(a:varname)
    call add(a:lines, 'let ' . a:varname . ' = "' . value . '"')
  endif
endfunction

function! arduino#GetArduinoDir() abort
  if exists('g:arduino_dir')
    return g:arduino_dir
  endif
  let executable = arduino#GetArduinoExecutable()
  let arduino_cmd = exepath(executable)
  let arduino_dir = fnamemodify(arduino_cmd, ':h')
  if s:OS == 'Darwin'
    let arduino_dir = fnamemodify(arduino_dir, ':h') . '/Java'
  endif
  return arduino_dir
endfunction

function! arduino#GetArduinoHomeDir() abort
  if exists('g:arduino_home_dir')
    return g:arduino_home_dir
  endif
  if s:OS == 'Darwin'
    return $HOME . "/Library/Arduino15"
  endif

  return $HOME . "/.arduino15"
endfunction

" Print the current configuration
function! arduino#GetInfo() abort
  let port = arduino#GetPort()
  if empty(port)
      let port = "none"
  endif
  let dirs = join(keys(s:hardware_dirs), ', ')
  if empty(dirs)
    let dirs = 'None'
  endif
  echo "Board         : " . g:arduino_board
  echo "Programmer    : " . g:arduino_programmer
  echo "Port          : " . port
  echo "Baud rate     : " . g:arduino_serial_baud
  echo "Hardware dirs : " . dirs
  echo "Verify command: " . arduino#GetArduinoCommand("--verify")
  echo "CLI command   : " . arduino#GetCLICompileCommand()
endfunction

" vim:fen:fdm=marker:fmr={{{,}}}
