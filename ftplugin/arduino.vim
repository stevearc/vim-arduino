if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1
if !exists('g:arduino_did_initialize')
  call arduino#LoadCache()
  call arduino#InitializeConfig()
  let g:arduino_did_initialize = 1
endif

" Use C rules for indentation
setl cindent

call arduino#RebuildMakePrg()

function! s:setAutoBaud()
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

if g:arduino_auto_baud
  au BufReadPost,BufWritePost *.ino,*.pde call s:setAutoBaud()
endif

function! s:getArduinoCommand(cmd)
  let cmd = a:cmd . " --board " . g:arduino_board
  if exists('g:arduino_serial_port')
    let cmd = cmd . " --port " . g:arduino_serial_port
  endif
  let cmd = cmd . " " . g:arduino_args . " " . expand('%')
  return cmd
endfunction

function! s:getBoards()
  let arduino_cmd = substitute(system('which arduino'), "\n*$", '', '')
  let arduino_cmd = resolve(arduino_cmd)
  let arduino_dir = fnamemodify(arduino_cmd, ':h')
  let cmd = "find ". arduino_dir . "/hardware -name 'boards.txt' | "
  let cmd = cmd . "xargs grep '^.*\.name' | "
  let cmd = cmd . "sed 's|.*/\\([^/]*\\)/\\([^/]*\\)/boards.txt:\\([^\.]*\\).*|\\1:\\2:\\3|' | "
  let cmd = cmd . "sort -u"
  return split(system(cmd))
endfunction

function! s:boardOrder(b1, b2)
  let c1 = split(a:b1, ':')[2]
  let c2 = split(a:b2, ':')[2]
  return c1 == c2 ? 0 : c1 > c2 ? 1 : -1
endfunction

let s:boardCb = {}
function! s:boardCb.onComplete(item, method)
  call s:ArduinoSetBoard(a:item)
endfunction
function! s:boardCb.onAbort()
endfunction

" Display a list of boards to the user and allow them to choose the active one
function! s:ArduinoChooseBoard()
  let boards = s:getBoards()
  call sort(boards, 's:boardOrder')
  try
    " If vim-fuzzyfinder is installed, use that to select the board.
    call fuf#callbackitem#launch('', 0, '>', s:boardCb, boards, 0)
  catch /E117/
    " Fall back to a simple inputlist()
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
    call s:ArduinoSetBoard(boards[choice - 1])
  endtry
endfunction

" Set the active board
function! s:ArduinoSetBoard(board)
  let g:arduino_board = a:board
  let g:_cache_arduino_board = a:board
  call arduino#RebuildMakePrg()
  call arduino#SaveCache()
endfunction

function! s:ArduinoVerify()
  let cmd = s:getArduinoCommand("arduino --verify")
  exe ":!" . cmd
  redraw!
  return v:shell_error
endfunction

function! s:ArduinoUpload()
  let cmd = s:getArduinoCommand("arduino --upload")
  exe ":silent !" . cmd
  redraw!
  return v:shell_error
endfunction

function! ArduinoGuessSerialPort()
  for l:glob in g:arduino_serial_port_globs
    let ports = glob(l:glob, 1, 1)
    if len(ports)
      return ports[0]
    endif
  endfor
endfunction

function! ArduinoGetSerialCmd()
  if exists('g:arduino_serial_port')
    let s:port = g:arduino_serial_port
  else
    let s:port = ArduinoGuessSerialPort()
  endif
  if !strlen(s:port)
    echoerr "Error! No serial port found"
    return
  endif
  let l:cmd = substitute(g:arduino_serial_cmd, '{port}', s:port, 'g')
  let l:cmd = substitute(l:cmd, '{baud}', g:arduino_serial_baud, 'g')
  return l:cmd
endfunction

function! s:ArduinoSerial()
  let cmd = ArduinoGetSerialCmd()
  if strlen($TMUX) && strlen(g:arduino_serial_tmux)
    exe ":silent !tmux " . g:arduino_serial_tmux . " '" . cmd . "'"
  else
    exe ":silent !" . cmd
  endif
  redraw!
endfunction

function! s:ArduinoUploadAndSerial()
  let ret = s:ArduinoUpload()
  if ret == 0
    call s:ArduinoSerial()
  endif
endfunction

command! ArduinoChooseBoard call s:ArduinoChooseBoard()
command! -nargs=1 ArduinoSetBoard call s:ArduinoSetBoard(<q-args>)
command! ArduinoVerify call s:ArduinoVerify()
command! ArduinoUpload call s:ArduinoUpload()
command! ArduinoSerial call s:ArduinoSerial()
command! ArduinoUploadAndSerial call s:ArduinoUploadAndSerial()
