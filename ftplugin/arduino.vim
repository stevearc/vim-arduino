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

if g:arduino_auto_baud
  au BufReadPost,BufWritePost *.ino,*.pde call arduino#SetAutoBaud()
endif

command! -buffer -bar ArduinoChooseBoard call arduino#ChooseBoard()
command! -buffer -bar -nargs=1 ArduinoSetBoard call arduino#SetBoard(<q-args>)
command! -buffer -bar ArduinoVerify call arduino#Verify()
command! -buffer -bar ArduinoUpload call arduino#Upload()
command! -buffer -bar ArduinoSerial call arduino#Serial()
command! -buffer -bar ArduinoUploadAndSerial call arduino#UploadAndSerial()
