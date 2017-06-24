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
* `:ArduinoChooseProgrammer` - Select the programmer from a list.
* `:ArduinoChoosePort` - Select the serial port from a list.
* `:ArduinoVerify` - Build the sketch.
* `:ArduinoUpload` - Build and upload the sketch.
* `:ArduinoSerial` - Connect to the board for debugging over a serial port.
* `:ArduinoUploadAndSerial` - Build, upload, and connect for debugging.

To make easy use of these, you may want to bind them to a key combination. You
can put the following in `.vim/ftplugin/arduino.vim`:

```vim
nnoremap <buffer> <leader>am :ArduinoVerify<CR>
nnoremap <buffer> <leader>au :ArduinoUpload<CR>
nnoremap <buffer> <leader>ad :ArduinoUploadAndSerial<CR>
nnoremap <buffer> <leader>ab :ArduinoChooseBoard<CR>
nnoremap <buffer> <leader>ap :ArduinoChooseProgrammer<CR>
```

If you want to add the board type to your status line, it's easy with the
following:

```vim
" my_file.ino [arduino:avr:uno]
function! MyStatusLine()
  return '%f [' . g:arduino_board . ']'
endfunction
setl statusline=%!MyStatusLine()
```

Or if you want something a bit fancier that includes serial port info:

```vim
" my_file.ino [arduino:avr:uno] [arduino:usbtinyisp] (/dev/ttyACM0:9600)
function! MyStatusLine()
  let port = arduino#GetPort()
  let line = '%f [' . g:arduino_board . '] [' . g:arduino_programmer . ']'
  if !empty(port)
    let line = line . ' (' . port . ':' . g:arduino_serial_baud . ')'
  endif
  return line
endfunction
setl statusline=%!MyStatusLine()
```


## License
Everything is under the [MIT
License](https://github.com/stevearc/vim-arduino/blob/master/LICENSE) except for
the wonderful syntax file, which was created by Johannes Hoff and copied from
[vim.org](http://www.vim.org/scripts/script.php?script_id=2654) and is under the
[Vim License](http://vimdoc.sourceforge.net/htmldoc/uganda.html).
