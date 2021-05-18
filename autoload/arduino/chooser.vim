" items should be a list of dictionary items with the following keys:
"   label   (optional) The string to display
"   value   The corresponding value passed to the callback
" items may also be a raw list of strings. They will be treated as values
function! arduino#chooser#Choose(title, raw_items, callback) abort
  let items = []
  let dict_type = type({})
  for item in a:raw_items
    if type(item) == dict_type
      call add(items, item)
    else
      call add(items, {'value': item})
    endif
  endfor

  if g:arduino_telescope_enabled
    call luaeval("require('arduino.telescope').choose('".a:title."', _A, '".a:callback."')", items)
  elseif g:arduino_ctrlp_enabled
    let ext_data = get(g:ctrlp_ext_vars, s:ctrlp_idx)
    let ext_data.lname = a:title
    let s:ctrlp_list = items
    let s:ctrlp_callback = a:callback
    call ctrlp#init(s:ctrlp_id)
  elseif g:arduino_fzf_enabled
    let s:fzf_counter += 1
    call fzf#run({
          \ 'source': s:ConvertItemsToLabels(items),
          \ 'sink': s:mk_fzf_callback(a:callback),
          \ 'options': '--prompt="'.a:title.': "'
          \ })
  else
    let labels = map(copy(s:ConvertItemsToLabels(items)), {i, l ->
          \ i < 9
          \   ? ' '.(i+1).') '.l
          \   : (i+1).') '.l
          \ })
    let labels = ["   " . a:title] + labels
    let choice = inputlist(labels)
    if choice > 0
      call call(a:callback, [items[choice-1]['value']])
    endif
  endif
endfunction

function! s:ConvertItemsToLabels(items) abort
  let longest = 1
  for item in a:items
    if has_key(item, 'label')
      let longest = max([longest, strchars(item['label'])])
    endif
  endfor
  return map(copy(a:items), 's:ChooserItemLabel(v:val, ' . longest . ')')
endfunction

function! s:ChooserItemLabel(item, ...) abort
  let pad_amount = a:0 ? a:1 : 0
  if has_key(a:item, 'label')
    let label = a:item['label']
    let spacing = 1 + max([pad_amount - strchars(label), 0])
    return label . repeat(' ', spacing) . '[' . a:item['value'] . ']'
  endif
  return a:item['value']
endfunction

function! s:ChooserValueFromLabel(label) abort
  " The label may be in the format 'label [value]'.
  " If so, we need to parse out the value
  let groups = matchlist(a:label, '\[\(.*\)\]$')
  if empty(groups)
    return a:label
  else
    return groups[1]
  endif
endfunction

" Ctrlp extension {{{1
if exists('g:ctrlp_ext_vars')
  if !exists('g:arduino_ctrlp_enabled')
    let g:arduino_ctrlp_enabled = 1
  endif
  let s:ctrlp_idx = len(g:ctrlp_ext_vars)
  call add(g:ctrlp_ext_vars, {
    \ 'init': 'arduino#chooser#ctrlp_GetData()',
    \ 'accept': 'arduino#chooser#ctrlp_Callback',
    \ 'lname': 'arduino',
    \ 'sname': 'arduino',
    \ 'type': 'line',
    \ })

  let s:ctrlp_id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
else
  let g:arduino_ctrlp_enabled = 0
endif

function! arduino#chooser#ctrlp_GetData() abort
  return s:ConvertItemsToLabels(s:ctrlp_list)
endfunction

function! arduino#chooser#ctrlp_Callback(mode, str) abort
  call ctrlp#exit()
  let value = s:ChooserValueFromLabel(a:str)
  call call(s:ctrlp_callback, [value])
endfunction

" fzf extension {{{1
if !exists('g:arduino_fzf_enabled')
  if exists("*fzf#run")
    let g:arduino_fzf_enabled = 1
  else
    let g:arduino_fzf_enabled = 0
  endif
endif

let s:fzf_counter = 0
function! s:fzf_leave(callback, item)
  call function(a:callback)(a:item)
  let s:fzf_counter -= 1
endfunction
function! s:mk_fzf_callback(callback)
  return { item -> s:fzf_leave(a:callback, s:ChooserValueFromLabel(item)) }
endfunction

" telescope extension {{{1
if !exists('g:arduino_telescope_enabled')
  let g:arduino_telescope_enabled = luaeval("pcall(require, 'telescope')")
endif

" vim:fen:fdm=marker:fmr={{{,}}}
