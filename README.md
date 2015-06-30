# vim-arduino
Vim plugin for compiling, uploading, and debugging arduino sketches. It makes
use of the Arduino IDE's [commandline
interface](https://github.com/arduino/Arduino/blob/master/build/shared/manpage.adoc)
(new in 1.5.x).

## Installation

vim-arduino works with [Pathogen](https://github.com/tpope/vim-pathogen).

```sh
cd ~/.vim/bundle/
git clone https://github.com/stevearc/vim-arduino
```

You also need to download the [Arduino
IDE](https://www.arduino.cc/en/Main/Software) (version 1.5 or newer) and make
sure the `arduino` command is in your PATH.

## Configuration

The docs have detailed information about configuring vim-arduino:
https://github.com/stevearc/vim-arduino/blob/master/doc/arduino.txt

The main commands you will want to use are:

* `:ArduinoChooseBoard` - Select the type of board from a list.
* `:ArduinoVerify` - Build the sketch.
* `:ArduinoUpload` - Build and upload the sketch.
* `:ArduinoSerial` - Connecto to the board for debugging over a serial port.
* `:ArduinoUploadAndSerial` - Build, upload, and connect for debugging.

To make easy use of these, you may want to bind them to a key combination. You
can put the following in `.vim/ftplugin/arduino.vim`:

```vim
nnoremap <buffer> <leader>m :ArduinoVerify<CR>
nnoremap <buffer> <leader>u :ArduinoUpload<CR>
nnoremap <buffer> <leader>d :ArduinoUploadAndSerial<CR>
```

If you want to add the board type to your status line, it's easy with the
following:

```vim
function! b:MyStatusLine()
  return '%f [' . g:arduino_board . ']'
endfunction
setl statusline=%!b:MyStatusLine()
```
