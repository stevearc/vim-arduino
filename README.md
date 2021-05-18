# vim-arduino
Vim plugin for compiling, uploading, and debugging arduino sketches. It uses
[arduino-cli](https://arduino.github.io/arduino-cli/latest/) when available, and
falls back to using the Arduino IDE's [commandline
interface](https://github.com/arduino/Arduino/blob/master/build/shared/manpage.adoc)
(new in 1.5.x).

## Installation

vim-arduino works with [Pathogen](https://github.com/tpope/vim-pathogen)

```sh
cd ~/.vim/bundle/
git clone https://github.com/stevearc/vim-arduino
```

and [vim-plug](https://github.com/junegunn/vim-plug)

```sh
Plug 'stevearc/vim-arduino'
```

Installation instructions for `arduino-cli` are here: https://arduino.github.io/arduino-cli/latest/installation/

Otherwise (or in addition to), download [Arduino
IDE](https://www.arduino.cc/en/Main/Software) (version 1.5 or newer). Linux
users make sure the `arduino` command is in your PATH.

## Platforms

vim-arduino should work with no special configuration on Linux and Mac. I have
not tested on Windows, but have heard that it works via WSL. See
[this issue](https://github.com/stevearc/vim-arduino/issues/4) for discussion.

## Configuration

The docs have detailed information about configuring vim-arduino
[here](https://github.com/stevearc/vim-arduino/blob/master/doc/arduino.txt).

The main commands you will want to use are:

* `:ArduinoChooseBoard` - Select the type of board from a list.
* `:ArduinoChooseProgrammer` - Select the programmer from a list.
* `:ArduinoChoosePort` - Select the serial port from a list.
* `:ArduinoVerify` - Build the sketch.
* `:ArduinoUpload` - Build and upload the sketch.
* `:ArduinoSerial` - Connect to the board for debugging over a serial port.
* `:ArduinoUploadAndSerial` - Build, upload, and connect for debugging.
* `:ArduinoInfo` - Display internal information. Useful for debugging issues with vim-arduino.

To make easy use of these, you may want to bind them to a key combination. You
can put the following in `.vim/ftplugin/arduino.vim`:

```vim
nnoremap <buffer> <leader>am :ArduinoVerify<CR>
nnoremap <buffer> <leader>au :ArduinoUpload<CR>
nnoremap <buffer> <leader>ad :ArduinoUploadAndSerial<CR>
nnoremap <buffer> <leader>ab :ArduinoChooseBoard<CR>
nnoremap <buffer> <leader>ap :ArduinoChooseProgrammer<CR>
```

If you wish to run these commands in tmux/screen/some other location, you can
make use of [vim-slime](https://github.com/jpalardy/vim-slime):

```vim
let g:arduino_use_slime = 1
```

### Status Line

If you want to add the board type to your status line, it's easy with the
following:

```vim
" my_file.ino [arduino:avr:uno]
function! MyStatusLine()
  return '%f [' . g:arduino_board . ']'
endfunction
setl statusline=%!MyStatusLine()
```

This is my personal configuration (again, inside `ftplugin/arduino.vim`)

```vim
" my_file.ino [arduino:avr:uno] [arduino:usbtinyisp] (/dev/ttyACM0:9600)
function! ArduinoStatusLine()
  let port = arduino#GetPort()
  let line = '[' . g:arduino_board . '] [' . g:arduino_programmer . ']'
  if !empty(port)
    let line = line . ' (' . port . ':' . g:arduino_serial_baud . ')'
  endif
  return line
endfunction
augroup ArduinoStatusLine
  autocmd! * <buffer>
  autocmd BufWinEnter <buffer> setlocal stl=%f\ %h%w%m%r\ %{ArduinoStatusLine()}\ %=\ %(%l,%c%V\ %=\ %P%)
augroup END
```
Note: if you are using the 'airline' plugin for the status line, you can display
this custom status part instead of the filename extension with:

```vim
autocmd BufNewFile,BufRead *.ino let g:airline_section_x='%{MyStatusLine()}'
```

## License
Everything is under the [MIT
License](https://github.com/stevearc/vim-arduino/blob/master/LICENSE) except for
the wonderful syntax file, which was created by Johannes Hoff and copied from
[vim.org](http://www.vim.org/scripts/script.php?script_id=2654) and is under the
[Vim License](http://vimdoc.sourceforge.net/htmldoc/uganda.html).
