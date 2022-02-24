let s:vim8_jobs = {}
let s:vim8_next_id = 0

function! arduino#job#run(cmd, callback)
  if has('nvim')
    call s:nvim_run(a:cmd, a:callback)
  else
    call s:vim8_run(a:cmd, a:callback)
  endif
endfunction

function! s:nvim_run(cmd, callback)
  let Callback = a:callback
  function On_exit(job_id, exit_code, event) closure
    if !a:exit_code
      call Callback()
    endif
  endfunction
  let job_id = jobstart(a:cmd, {
        \ 'on_exit': funcref('On_exit'),
        \ 'on_stderr': funcref('s:nvim_on_stderr'),
        \ 'stderr_buffered': v:true,
        \})
  if job_id == 0
    echoerr 'Error running job: invalid arguments'
  elseif job_id == -1
    echoerr 'Error running job: command is not executable'
  endif
endfunction

function! s:nvim_on_stderr(job_id, data, name)
  for line in a:data
    if !empty(line)
      echoerr line
    endif
  endfor
endfunction

function! s:nvim_on_exit(job_id, exit_code, event)
  if a:exit_code
    echoerr 'Error running job ' . a:exit_code
  end
endfunction

function! s:vim8_run(cmd, callback)
  let job_id = s:vim8_next_id
  let s:vim8_next_id += 1
  let Callback = a:callback
  function! OnClose(channel) closure
    let job = s:vim8_jobs[job_id]
    while ch_status(a:channel, {'part': 'err'}) ==? 'buffered'
      echoerr ch_read(a:channel, {'part': 'err'})
    endwhile
    call remove(s:vim8_jobs, job_id)
    let exit_code = job_info(job)['exitval']
    if exit_code
      echoerr 'Error running job ' . exit_code
    else
      call Callback()
    endif
  endfunction
  let job = job_start(a:cmd, {'close_cb': 'OnClose'})
  let s:vim8_jobs[job_id] = job
endfunction
