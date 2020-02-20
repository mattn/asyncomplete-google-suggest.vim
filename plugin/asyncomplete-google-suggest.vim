if exists('g:asyncomplete_google_suggest_loaded')
    finish
endif
let g:asyncomplete_google_suggest_loaded = 1
let s:url = 'https://suggestqueries.google.com/complete/search?client=youtube&q=%s&hjson=t&hl=ja&ie=UTF8&oe=UTF8'

function! s:urlencode(q) abort
  let l:ret = ''
  let l:q = iconv(a:q, &encoding, 'utf-8')
  for l:i in range(0, len(l:q))
    let l:ch = l:q[l:i]
    if ch =~# '[0-9A-Za-z-._~!''()*]'
      let l:ret .= ch
    elseif ch == ' '
      let l:ret .= '+'
    else
      let l:ret .= printf('%%%02X', char2nr(l:ch))
    endif
  endfor
  return l:ret
endfunction

function! s:handle_stdout(results, job_id, data, event_type) abort
  call add(a:results, join(a:data, ''))
endfunction

function! s:handle_exit(ctx, opt, base, startcol, results, job_id, data, event_type) abort
  let l:result = json_decode(join(a:results, ''))
  let l:items = []
  for l:m in l:result[1]
    call add(l:items, l:m[0])
  endfor
  let l:line = getline('.')
  "call setline('.', l:line[: a:startcol - 1] . l:line[a:startcol + len(a:base) :])
  call asyncomplete#complete(a:opt['name'], a:ctx, a:startcol + 1, l:items)
endfunction

function! s:handle_timer(opt, ctx, timer) abort
  let l:typed = a:ctx['typed']
  let l:startcol = match(l:typed, '\<\S*$')
  if l:startcol == -1
    return
  endif
  let l:base = getline('.')[l:startcol : col('.')]
  let l:args = ['curl', '-s', printf(s:url, s:urlencode(l:base))]
  let l:results = []
  let s:jobid = async#job#start(args, {
  \ 'on_stdout': function('s:handle_stdout', [l:results]),
  \ 'on_exit': function('s:handle_exit', [a:ctx, a:opt, l:base, l:startcol, l:results]),
  \ })
endfunction

function! s:completor(opt, ctx) abort
  call timer_start(500, function('s:handle_timer', [a:opt, a:ctx]))
endfunction

function! s:filter(matches, startcol, base) abort
    let l:matches = a:matches
    let l:startcol = a:startcol
    let l:base = a:base
    let l:startcols = []
    let l:items = []
    for l:item in l:matches['items']
        let l:startcols += [l:startcol]
        call add(l:items, l:item)
    endfor
    return [l:items, l:startcols]
endfunction

call asyncomplete#register_source({
\ 'name': 'google_suggest',
\ 'whitelist': ['*'],
\ 'completor': function('s:completor'),
\ 'filter': function('s:filter'),
\ })
