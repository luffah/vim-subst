" subst.vim   -- substitute and search with more lazyness
" @Author:      luffah (luffah AT runbox com)
" @License:     AGPL (see http://www.gnu.org/licenses/agpl)
" @Created:     2018-00-00
" @Last Change: 2026-05-21
" @Revision:    1
"
" @Overview
" Features:
"   * substitution with options at the end :
"        * options g,n,c,I,#,p,n,e,i,& have same meaning that in s///opt
"        * option % and 2,4 will work as range
"        * option h to add in history
"        * option v to revert src & dest
"        * option f or ~ for a fuzzy substitution
"        * option x to exchange values instead of substitute
"          Note : with x option, regexp are not supported
"   * command arguments are completed in wildmode (include tags)
"
" Usage:
"   " Commande help
"   :S -h
"   " Search
"   :S pattern
"   " Substitute
"   :S pattern replacement options
"   " Search  (SQ is for Quoted Search/Subst, simple and double quote are useable)
"   :SQ 'pattern'
"   " Substitute
"   :SQ 'pattern','replacement','options'

function! s:help()
    let l:ret = "Usage:\n :S pattern replacement options\n :SQ 'pattern','replacement','options'\n"
    let l:ret .= "Options:\n"
    let l:ret .= "* g,n,c,I,#,p,n,e,i,& have same meaning that in s///opt\n"
    let l:ret .= "* % and 2,4 will work as range\n"
    let l:ret .= "* h to add in history\n"
    let l:ret .= "* v to revert ange revert source and destination pattern\n"
    let l:ret .= "* x to exchange values instead of substitute (no regexp support)\n"
    let l:ret .= "* ~ or f(uzzy) to substitute similar values (value.name value_name ValueName)\n"
    return l:ret
endfunction

let s:_compl_subst_idx_mood=0
function! s:compl_subst(A,nargs,retry_mode,max_retry)
    let l:words={}
    if a:retry_mode > a:max_retry || (a:nargs < 2 && a:retry_mode > 1)
        return []
    endif 
    let l:retry_mode = a:retry_mode
    let l:retry_larger=a:retry_mode == 1
    let l:retry_with_other_buffers=a:retry_mode == 2
    let l:retry_with_tags=a:retry_mode == 3
    let l:prefix = ''
    if a:nargs == 3
        return map(split('gncI#pnei&%hvx', '\zs'), "a:A.v:val")
    endif
    let l:A=strpart(a:A,0,len(a:A))
    if l:A !~ '\~'
        let s:_compl_subst_idx_mood = 0
    elseif a:A[len(a:A)-1] == '~'
        let s:_compl_subst_idx_mood = 4
    endif
    if s:_compl_subst_idx_mood  > 0
        let s:_compl_subst_idx_mood -= 1
        let l:A=substitute(l:A,'\~', '', 'g')
        let l:retry_mode = 99
        let l:retry_larger = 1
        let l:retry_with_tags = 1
        let l:retry_with_other_buffers = 1
    endif
    if l:retry_with_tags
        for l:i in taglist('.')
            let l:w = l:i['name']
            let l:words[l:w] = (get(l:words,l:w,0)+1)
        endfor
    endif
    if l:retry_with_other_buffers
        let l:all_lines=[]
        let l:all = range(0, bufnr('$'))
        let l:buflist = []
        for l:b in l:all
            if buflisted(l:b)
                call add(l:buflist, bufname(l:b))
            endif
        endfor
        exe 'silent! keepj noautocmd vimgrep /'.a:A.'/ '.join(l:buflist)
        for l:i in getqflist() 
            call add(l:all_lines, l:i['text'])
        endfor
    elseif l:retry_larger
        let l:all_lines=getline(1,line('$'))
    else
        let l:i=line('.')
        let l:all_lines=getline(l:i, l:i)
    endif
    if l:A =~ ' '
        let l:aa = a:A
        for l:i in l:all_lines
            let l:new_str = matchstr(l:i, l:aa .'\S*\s\?')
            if len(l:new_str)
                let l:words[l:new_str] = l:new_str
            endif
        endfor
        let l:ret = keys(l:words)
    else
        let l:last=strpart(a:A,len(a:A)-1)
        let l:chars=split(l:A,'\zs')
        let l:nonword=[]
        let l:full_line_mode = 0
        for l:i in l:chars
            if l:i =~ '\W'
                call add(l:nonword,l:i)
            endif
        endfor
        if l:last =~ '\W'
            let l:splitter='\(\s\+\|\s*['.l:last.']\s*\)'
        else
            let l:A=a:A
            let l:splitter='[^0-9A-Za-z_'.join(uniq(l:nonword),'').']\+'
        endif
        for l:i in l:all_lines
            for l:w in filter(split(l:i, l:splitter),'!empty(v:val)')
                let l:words[l:w]=(get(l:words, l:w, 0) + 1)
            endfor
        endfor
        let l:ret=filter(keys(l:words),"v:val =~ '^".escape(l:A,"'")."'")
    endif
    if len(l:ret) == 0 
        return s:compl_subst(a:A, a:nargs, l:retry_mode + 1, a:max_retry)
    endif
    if len(l:ret) == 1
        let s:_compl_subst_idx_mood=0
    endif
    return l:ret
endfunction

function! _CompSubst(A,L,P)
    return s:compl_subst(a:A, len(split(a:L))-1, 0, 3)
endfunction
function! _CompSubstQuoted(A,L,P)
    let l:sta = match(a:L, " ")
    let l:argoffset = 1
    if l:sta != -1
        let l:L = strpart(a:L, l:sta+1)
    else
        let l:sta = match(a:L, "['\"]")
        let l:argoffset = 0
        if l:sta != -1
            let l:L = strpart(a:L, l:sta)
        else
            return
        endif
    endif
    let l:defquote="'"
    if l:L =~ "^['\"]"
        let l:defquote=l:L[0]
    endif
    let l:args=split(l:L, l:defquote.'\s*,\s\?')
    let l:A = ''
    let l:b_start = 0
    if len(l:args)
        let l:A = l:args[-1]
        let l:b_start = len(l:A) - len(a:A) - l:argoffset
        if l:L =~ "^['\"]"
            let l:defquote=l:L[0]
            let l:A = strpart(l:A, 1)
        endif
        " unsilent echo '-'.l:defquote.'-'
        " sleep 1
        " unsilent echo '-'.l:A.'-'
        " sleep 1
        if l:defquote == "'"
            " let l:A = substitute(l:A,"'\\?\\([^']*[^'\\]\\)'\\?,\\?",'\1','')
            " unsilent echo '-'.l:A.'-'
            " sleep 1
            let l:A = substitute(l:A,"''","'",'g')
            " let l:A = escape(l:A,'"')
            " let l:A = substitute(l:A,"'",'"','g')
        elseif l:defquote == '"'
            " let l:A = substitute(l:A,'"\?\([^"]*[^\"]\)"\?,\?','\1','')
            let l:A = substitute(l:A,'\\\"','"','g')
            " let l:A = escape(l:A,"'")
            " let l:A = substitute(l:A,'"',"'",'g')
        endif
        " unsilent echo '-'.l:A.'-'
        " sleep 1
    endif
    let l:ret = s:compl_subst(l:A, len(l:args), 0, 2)
    if  l:A =~ ' '
        let l:ret = map(l:ret, "strpart(v:val,l:b_start)")
    endif
    if (l:A !~ "^".l:defquote || l:A =~ ' ')
        if l:defquote == "'"
            let l:ret = map(l:ret, "substitute(v:val,\"'\", \"''\", 'g')")
        elseif l:defquote == '"'
            let l:ret = map(l:ret, "escape(escape(v:val,'\"'),'\')")
        endif
    endif
    return l:ret
endfunction

function! s:is_camel_case(word) 
  return a:word =~ '\<\u\|\U\u'
endfunction
function! s:to_camel_case(word, sep) 
  return substitute(a:word,
        \ '\(\%(\<\l\+\)\%('.a:sep.'\)\@=\)\|'.a:sep.'\(\l\)',
        \ '\u\1\2',
        \ 'g')
endfunction
function! s:from_camel_case(word, sep) 
  return substitute(a:word, 
        \ '\<\u\|\l\u',
        \ "\\= join(split(tolower(submatch(0)), '\\zs'), '".a:sep."')",
        \ 'g')
endfunction

"@function subst#(from, [to, [flag]])
"like s/from/to/flag with additionnal options. See :S -h
function! subst#(from,...) range
  let l:before=''
  let l:vscope=''
  let l:after=''
  let l:histadd=0
  let l:exchange=0
  let l:fuzzy=0
  let l:searchonly=0
  if !len(a:000)
    if a:from == '-h' || a:from == 'help' 
      echo s:help()
      return
    endif
    let l:searchonly=1
  endif
  let l:to = get(a:000, 0, '')
  let l:from = a:from
  let l:args = join(a:000[1:],'')
  let l:linerange = matchstr(l:args,"[+-]\?\d\+,[+-]\?\d\+")
  if len(l:linerange)
    let l:before = l:linerange
    let l:args = substitute(l:args,"\([+-]\?\d\+,[+-]\?\d\+\|%\)",'','g')
  elseif (a:firstline != a:lastline) 
    let l:before = a:firstline.','.a:lastline
  endif
  if len(l:before) 
    let l:vscope = '\%V'
  endif
  if match(l:args, 'help') > -1 || match(l:args, '-h') > -1
    echo s:help()
    return
  endif
  for l:i in split(l:args,'\zs')
    if l:i == '~' || l:i == 'f'
      let l:fuzzy = 1
    elseif l:i == 'r' || l:i == 'h'
      let l:histadd=1
    elseif l:i == 'v'
      let l:tmp = l:from
      let l:from = l:to
      let l:to = l:tmp
    elseif l:i == 'x'
      let l:exchange = 1
    elseif l:i == '%'
      let l:before='%'
    elseif match(['g' , 'c' , 'I' , '#', 'p' , 'n' , 'e' , 'i' , '&'], l:i) > -1
      let l:after.=l:i
    endif
  endfor
  if l:searchonly || l:fuzzy
      let l:from = substitute(l:from,  "[\"']\\([^\"']*\\)[\"']", "['\"]\\1['\"]", 'g')
  endif
  if l:searchonly
      let l:command = '/'.substitute(l:vscope.l:from,'\/','\\\/','g')
  elseif l:fuzzy
    let l:fuzzy_fromto = [[substitute(l:from, '\.', '\.', 'g'), substitute(l:to, '\.', '\.', 'g')]]
    if s:is_camel_case(l:to) && s:is_camel_case(l:from)
      let l:fuzzy_fromto += [
            \ [s:from_camel_case(l:from, '\.'), s:from_camel_case(l:to, '\.')],
            \ [s:from_camel_case(l:from, '_'), s:from_camel_case(l:to, '_')]
            \ ]
    elseif l:from =~ '\.' && l:to =~ '\.'
      let l:fuzzy_fromto += [
            \ [s:to_camel_case(l:from, '\.'), s:to_camel_case(l:to, '\.')],
            \ [substitute(l:from, '\.', '_', 'g'), substitute(l:to, '\.', '_', 'g')]
            \ ]
    elseif l:from =~ '_' && l:to =~ '_'
      let l:fuzzy_fromto += [
            \ [s:to_camel_case(l:from, '_'), s:to_camel_case(l:to, '_')],
            \ [substitute(l:from, '_', '\.', 'g'), substitute(l:to, '_', '\.', 'g')]
            \ ]
    endif
    let l:command=''
    let l:max = len(l:fuzzy_fromto)
    for l:idx in range(l:max)
      let l:item = l:fuzzy_fromto[l:idx]
      let l:command.=l:before.'s/'.substitute(l:item[0],'\/','\\\/','g').'/'.substitute(l:item[1],'\/','\\\/','g').'/'.l:after
      if l:idx < (l:max - 1)
        let l:command.=' | '
      endif
    endfor
  elseif l:exchange
    let l:command=l:before
    let l:command.='s/'.substitute(l:vscope.l:from,'\/','\\\/','g').'/#-?#FROM\/TO#?-#/'
    let l:command.=l:after.'|'.l:before
    let l:command.='s/'.substitute(l:to,'\/','\\\/','g').'/#-?#TO\/FROM#?-#/'
    let l:command.=l:after.'|'.l:before
    let l:command.='s/#-?#TO\/FROM#?-#/'.substitute(l:from,'\/','\\\/','g').'/'
    let l:command.=l:after.'|'.l:before
    let l:command.='s/#-?#FROM\/TO#?-#/'.substitute(l:to,'\/','\\\/','g').'/'
    let l:command.=l:after
  else 
    let l:command=l:before.'s/'.substitute(l:from,'\/','\\\/','g').'/'.substitute(l:to,'\/','\\\/','g').'/'.l:after
  endif
  " echo l:command
  if l:histadd 
    call histadd('cmd',l:command)
  endif
  silent! call setreg('/',l:from)
  silent! exe l:command
endfunction

command! -nargs=* -range -complete=customlist,_CompSubst S <line1>,<line2>call subst#(<f-args>)
command! -nargs=* -range -complete=customlist,_CompSubstQuoted SQ <line1>,<line2>call subst#(<args>)

"@function subst#exchange(line, word1, word2, flag)
"returns line with exchanged words.
fu! subst#exchange(line, word1, word2, flag)
    let [l:words1,l:words2] =  type(a:word1) == type([]) ? [a:word1, a:word2] : [[a:word1, a:word2]]
    for l:i in range(len(l:words1))
        if a:line =~# l:words2[l:i]
            return substitute(a:line, l:word2[l:i],  l:word1[l:i], a:flag)
        endif
    endfor
    for l:i in range(len(l:words2))
        if a:line =~# l:words1[l:i]
            return substitute(a:line, l:word1[l:i],  l:word2[l:i], a:flag)
        endif
    endfor
    return a:line
endfu
