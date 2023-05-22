# vim-arduino

Vim plugin for compiling, uploading, and debugging arduino sketches. It uses
[arduino-cli](https://arduino.github.io/arduino-cli/latest/) when available
(recommended), and falls back to using the Arduino IDE's [commandline
interface](https://github.com/arduino/Arduino/blob/master/build/shared/manpage.adoc)
(new in 1.5.x).

## Installation

vim-arduino works with all the usual plugin managers

<details>
  <summary>Packer (Neovim only)</summary>

```lua
require('packer').startup(function()
    use {'stevearc/vim-arduino'}
end)
```

</details>

<details>
  <summary>Paq (Neovim only)</summary>

```lua
require "paq" {
    {'stevearc/vim-arduino'};
}
```

</details>

<details>
  <summary>vim-plug</summary>

```vim
Plug 'stevearc/vim-arduino'
```

</details>

<details>
  <summary>dein</summary>

```vim
call dein#add('stevearc/vim-arduino')
```

</details>

<details>
  <summary>Pathogen</summary>

```sh
git clone --depth=1 https://github.com/stevearc/vim-arduino.git ~/.vim/bundle/
```

</details>

<details>
  <summary>Neovim native package</summary>

```sh
git clone --depth=1 https://github.com/stevearc/vim-arduino.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/pack/vim-arduino/start/vim-arduino
```

</details>

<details>
  <summary>Vim8 native package</summary>

```sh
git clone --depth=1 https://github.com/stevearc/vim-arduino.git \
  "$HOME"/.vim/pack/vim-arduino/start/vim-arduino
```

</details>

## Requirements

Linux and Mac are tested and functioning. I have not tested on Windows, but have
heard that it works via WSL. See [this
issue](https://github.com/stevearc/vim-arduino/issues/4) for discussion.

It is recommended to use `arduino-cli`, installation instructions here: https://arduino.github.io/arduino-cli/latest/installation/

However it is also possible to use the arduino IDE directly. Download [Arduino
IDE](https://www.arduino.cc/en/Main/Software) (version 1.5 or newer). Linux
users make sure the `arduino` command is in your PATH.

## Commands

| Command                   | arg          | description                                                                 |
| ------------------------- | ------------ | --------------------------------------------------------------------------- |
| `ArduinoAttach`           | [port]       | Automatically attach to your board (see `arduino-cli board attach -h`)      |
| `ArduinoChooseBoard`      | [board]      | Select the type of board. With no arg, will present a choice dialog.        |
| `ArduinoChooseProgrammer` | [programmer] | Select the programmer. With no arg, will present a choice dialog.           |
| `ArduinoChoosePort`       | [port]       | Select the serial port. With no arg, will present a choice dialog.          |
| `ArduinoVerify`           |              | Build the sketch.                                                           |
| `ArduinoUpload`           |              | Build and upload the sketch.                                                |
| `ArduinoSerial`           |              | Connect to the board for debugging over a serial port.                      |
| `ArduinoUploadAndSerial`  |              | Build, upload, and connect for debugging.                                   |
| `ArduinoInfo`             |              | Display internal information. Useful for debugging issues with vim-arduino. |

To make easy use of these, you may want to bind them to a key combination. You
can put them in `ftplugin/arduino.vim`:

```vim
" Change these as desired
nnoremap <buffer> <leader>aa <cmd>ArduinoAttach<CR>
nnoremap <buffer> <leader>av <cmd>ArduinoVerify<CR>
nnoremap <buffer> <leader>au <cmd>ArduinoUpload<CR>
nnoremap <buffer> <leader>aus <cmd>ArduinoUploadAndSerial<CR>
nnoremap <buffer> <leader>as <cmd>ArduinoSerial<CR>
nnoremap <buffer> <leader>ab <cmd>ArduinoChooseBoard<CR>
nnoremap <buffer> <leader>ap <cmd>ArduinoChooseProgrammer<CR>
```

## Configuration

By default you should not _need_ to set any options for vim-arduino to work
(especially if you're using `arduino-cli`, which tends to behave better). If
you want to see what's available for customization, there is detailed
information [in the vim docs](https://github.com/stevearc/vim-arduino/blob/master/doc/arduino.txt).

## Integrations

### Dialog / picker plugins

The built-in mechanism for choosing items (e.g. `:ArduinoChooseBoard`) uses
`inputlist()` and is not very pretty or ergonomic. If you would like to improve
the UI, there are two approaches:

- **Neovim:** override `vim.ui.select` (e.g. by using a plugin like [dressing.nvim](https://github.com/stevearc/dressing.nvim))
- **Vim8:** install [ctrlp](https://github.com/ctrlpvim/ctrlp.vim) or [fzf](https://github.com/junegunn/fzf.vim). They will automatically be detected and used

### Tmux / screen

If you want to run the arduino commands in a separate tmux or screen pane, use
[vim-slime](https://github.com/jpalardy/vim-slime). By setting `let g:arduino_use_slime = 1` vim-arduino will send the commands via `slime#send()` instead of running them inside a vim terminal.

### Status Line

You may want to display the arduino state in your status line. There are four
pieces of data you may find interesting:

- **g:arduino_board** - the currently selected board
- **g:arduino_programmer** - the currently selected programmer
- **g:arduino_serial_baud** - the baud rate that will be used for Serial commands
- **arduino#GetPort()** - returns the port that will be used for communication

An example with vanilla vim or nvim, added to `ftplugin/arduino.vim`:

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

To do the same thing with [vim-airline](https://github.com/vim-airline/vim-airline):

```vim
autocmd BufNewFile,BufRead *.ino let g:airline_section_x='%{MyStatusLine()}'
```

For [lualine](https://github.com/nvim-lualine/lualine.nvim) (Neovim only) I use
the following function:

```lua
local function arduino_status()
  if vim.bo.filetype ~= "arduino" then
    return ""
  end
  local port = vim.fn["arduino#GetPort"]()
  local line = string.format("[%s]", vim.g.arduino_board)
  if vim.g.arduino_programmer ~= "" then
    line = line .. string.format(" [%s]", vim.g.arduino_programmer)
  end
  if port ~= 0 then
    line = line .. string.format(" (%s:%s)", port, vim.g.arduino_serial_baud)
  end
  return line
end
```

## License

Everything is under the [MIT
License](https://github.com/stevearc/vim-arduino/blob/master/LICENSE) except for
the wonderful syntax file, which was created by Johannes Hoff and copied from
[vim.org](http://www.vim.org/scripts/script.php?script_id=2654) and is under the
[Vim License](http://vimdoc.sourceforge.net/htmldoc/uganda.html).
