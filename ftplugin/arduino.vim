if exists('b:did_arduino_ftplugin')
  finish
endif
let b:did_arduino_ftplugin = 1
call arduino#InitializeConfig()

" Use C rules for indentation
setl cindent

call arduino#RebuildMakePrg()

if g:arduino_auto_baud
  aug ArduinoBaud
    au!
    au BufReadPost,BufWritePost *.ino call arduino#SetAutoBaud()
  aug END
endif
