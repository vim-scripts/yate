"====================================================================================
" Author:		Evgeny V. Podjachev <evNgeny.poOdjSacPhev@gAmail.cMom-NOSPAM>
"
" License:		This program is free software: you can redistribute it and/or modify
"				it under the terms of the GNU General Public License as published by
"				the Free Software Foundation, either version 3 of the License, or
"				any later version.
"				
"				This program is distributed in the hope that it will be useful,
"				but WITHOUT ANY WARRANTY; without even the implied warranty of
"				MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
"				GNU General Public License for more details
"				(http://www.gnu.org/copyleft/gpl.txt).
"
" Description:	This plugin makes search in tags more convenient.
" 				It holds query and search result in one buffer for faster jump to 
" 				desired tag.
"
" Installation:	Just drop this file in your plugin directory.
"
" Usage:		Command :YATE toggles visibility of search buffer.
" 				Parameter g:YATE_window_height sets height of search buffer. Default = 15
" 				Parameter g:YATE_strip_long_paths enables(1)/disables(0) cutting of long file paths. Default = 1.
" 				Parameter g:YATE_enable_real_time_search enables(1)/disables(0) as-you-type search. Default = 1.
" 				Parameter g:YATE_min_symbols_to_search sets search string length threshold 
" 				after which as-you-type search will start. Default = 4.
"
" 				To get list of matching tags set cursor on string containing expression
" 				to search (in YATE buffer) then press <Tab> or <Enter>, never mind if 
" 				you are in normal or insert mode.
"
" 				To open tag location set cursor on string with desired tag and
" 				press <Enter> or double click left mouse button on this string, 
" 				never mind if you are in normal or insert nmode.
" 				To open tag in new tab press <Ctrl-Enter>, in new horizontal
" 				splitted buffer <Shift-Enter>, in new vertical splitted buffer 
" 				<Ctrl-Shift-Enter>.
"
" Version:		1.0.1
"
" ChangeLog:	1.0.1:	Fixed serious bug which caused the impossibility of inputing
"						characters nowhere but at the and of the search string.
"						Add support of GetLatestVimScripts.
"
"				1.0.0:	Added automatic search after input of any character
"						(so called as-you-type search).
" 						Long file paths may be cut to fit line width.
" 						Fixed bug preventing jump by tags containing ~ (e.g.
"						c++ destructors).
"						Fixed bug preventing jump by tags in files with mixed
"						line ends (Win/Unix).
"
"				0.9.2:	Attempt to search empty string doesn't produce error.
" 						Replacement of modified buffer works correct.
"						Close YATE buffer externally (by :q, ZZ etc.) dosn't break 
"						its visibility toggle.
"						Fixed bug leading to failure to open to tag containing square brackets.
"
"				0.9.1:	Search string isn't cleared if there are no matched
"						tags.
"						Bug fixes.
"
"				0.9:	First release
"
" GetLatestVimScripts: 2068 8378 :AutoInstall: yate.vim
"====================================================================================
if exists( "g:loaded_YATE" )
	finish
endif

let g:loaded_YATE = 1

" Check to make sure the Vim version 700 or greater.
if v:version < 700
  echo "Sorry, YATE only runs with Vim 7.0 and greater"
  finish
endif

if !exists("g:YATE_window_height")
	let g:YATE_window_height = 15
endif

if !exists("g:YATE_strip_long_paths")
	let g:YATE_strip_long_paths = 1
endif

if !exists("g:YATE_enable_real_time_search")
	let g:YATE_enable_real_time_search = 1
endif

if !exists("g:YATE_min_symbols_to_search")
	let g:YATE_min_symbols_to_search = 4
endif

command! -bang YATE :call <SID>ToggleTagExplorerBuffer()

fun <SID>GotoTag(open_command)
	let str=getline(".")

	if !exists("s:tags_list") || !len(s:tags_list) || match(str,"^.*|.*|.*|.*$")
		call <SID>GenerateTagsListCB()
		return
	endif

	let index=str2nr(str)
	
	cal <SID>OnLeaveBuffer()

	exe ':wincmd p'
	exe ':'.s:yate_winnr.'bd!'
	let s:yate_winnr=-1

	cal <SID>OnLeaveBuffer()

	exe ':'.a:open_command.' '.s:tags_list[index]['filename']
	let str=substitute(s:tags_list[index]['cmd'],"\*","\\\\*","g")
	let str=substitute(str,"\[","\\\\[","g")
	let str=substitute(str,"\]","\\\\]","g")
	let str=substitute(str,"\\~","\\\\~","g")
	let str=substitute(str,"\$/","*$/","g")
	exe str
	" Without it you should press Enter once again some times.
	exe 'normal Q'
endfun

fun <SID>AutoCompleteString(str)
	if !exists("s:tags_list") || !len(s:tags_list)
		return a:str
	endif

	let res=a:str
	" find shortest name
	let sname=9999
	let shortestName=""

	for i in s:tags_list
		let l=strlen(i['name'])

		if l<sname
			let sname=l
			let shortestName=i['name']
		endif
	endfor

	let start_index=stridx(shortestName,res)+strlen(res)

	cal append(0,shortestName)

	for j in range(start_index,strlen(shortestName))
		let tmp=res.shortestName[j]
		let ok=1
		for i in s:tags_list
			let isMatch=stridx(i['name'],tmp)
			if isMatch==-1
				return res
			endif
		endfor
		let res=tmp
	endfor
	return res
endfun

fun <SID>PrintTagsList()
	" clear buffer
	exe 'normal ggdG'

	if !exists("s:tags_list")
		return
	endif

	cal append(0,s:user_line)
	exe 'normal dd$'

	if !len(s:tags_list)
		return
	endif

	" find the longest names, kind, filename
	let lname=0
	let lkind=0

	for i in s:tags_list
		let lnm=strlen(i['name'])
		let lk=strlen(i['kind'])

		if lnm>lname
			let lname=lnm
		endif
		if lk>lkind
			let lkind=lk
		endif
	endfor

	let window_width=winwidth('$')
	let counter=0
	for i in s:tags_list
		let str=printf("%3d | %s",counter,i["name"])
		for j in range(strlen(i["name"]),lname)
			let str=str.' '
		endfor
		let str=str.'| '.i["kind"]
		for j in range(strlen(i["kind"]),lkind)
			let str=str.' '
		endfor

		let str=str.'| '
		if !g:YATE_strip_long_paths
			let str=str.i["filename"]
		else
			let sp=window_width-strlen(str)-3

			if strlen(i["filename"])<=sp
				let str=str.i["filename"]
			else
				let str=str.'...'.strpart(i["filename"],strlen(i["filename"])-sp+3,sp-3)
			endif
		endif
		
		cal append(line("$"),str)

		let counter=counter+1
	endfor
endfun

fun <SID>GenerateTagsList(str,auto_compl)
	" get tags list
	if !strlen(a:str)
		return
	endif
	let s:user_line=a:str
	let s:tags_list=taglist(s:user_line)

	if a:auto_compl
		let s:user_line=<SID>AutoCompleteString(s:user_line)
	endif
	cal <SID>PrintTagsList()
	exe 'normal l'
endfun

fun <SID>AppendChar(char)
	let save_cursor = winsaveview()

	let str=getline('.')
	let str=strpart(str,0,col(".")-1).a:char.strpart(str,col(".")-1)

	exe 'normal ggdG'
	cal append(0,str)
	exe 'normal dd'

	if strlen(str)>=g:YATE_min_symbols_to_search
		cal <SID>GenerateTagsList(str,0)
	endif
	cal winrestview(save_cursor)
	exe 'normal l'
endfun

fun <SID>OnEnterBuffer()
	let s:old_ve = &ve
	setlocal ve=all
endfun

fun <SID>OnLeaveBuffer()
	if exists("s:old_ve")
		let &ve=s:old_ve
	endif
endfun

fun <SID>GenerateTagsListCB()
	cal <SID>GenerateTagsList(getline('.'),1)
endfun

fun! <SID>ToggleTagExplorerBuffer()
	if !exists("s:yate_winnr") || s:yate_winnr==-1
		exe "bo".g:YATE_window_height."sp YATE"
		cal <SID>PrintTagsList()

		exe "verbose inoremap <silent> <buffer> <Tab> <C-O>:cal <SID>GenerateTagsListCB()<CR>"

		exe "verbose inoremap <silent> <buffer> <Enter> <C-O>:cal <SID>GotoTag('e')<CR>"
		exe "verbose noremap <silent> <buffer> <Enter> :cal <SID>GotoTag('e')<CR>"
		exe "verbose noremap <silent> <buffer> <2-leftmouse> :cal <SID>GotoTag('e')<CR>"
		exe "verbose inoremap <silent> <buffer> <2-leftmouse> <C-O>:cal <SID>GotoTag('e')<CR>"

		exe "verbose inoremap <silent> <buffer> <C-Enter> <C-O>:cal <SID>GotoTag('tabnew')<CR>"
		exe "verbose noremap <silent> <buffer> <C-Enter> :cal <SID>GotoTag('tabnew')<CR>"

		exe "verbose inoremap <silent> <buffer> <S-Enter> <C-O>:cal <SID>GotoTag('sp')<CR>"
		exe "verbose noremap <silent> <buffer> <S-Enter> :cal <SID>GotoTag('sp')<CR>"

		exe "verbose inoremap <silent> <buffer> <C-S-Enter> <C-O>:cal <SID>GotoTag('vs')<CR>"
		exe "verbose noremap <silent> <buffer> <C-S-Enter> :cal <SID>GotoTag('vs')<CR>"

		if g:YATE_enable_real_time_search
			for c in split("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890~:-=_+[]{};\\\':<>?,./ ", '\zs')
				exec 'inoremap <silent> <buffer> '.c.' <C-O>:cal <SID>AppendChar("'.c.'")<CR>'
			endfor
		endif

		" color output
		syn match YATE_search_string #\%^.*$#
		syn match YATE_tag_number #^\s*\d\+ # nextgroup=YATE_tag_name
		syn region YATE_tag_name matchgroup=Macro start=/|/ end='|' nextgroup=YATE_tag_kind
		syn match YATE_tag_kind # \h\+ # nextgroup=YATE_tag_filename 
		syn region YATE_tag_filename matchgroup=Macro start='|' end=/$/

		hi def link YATE_tag_number Number
		hi def link YATE_tag_name Identifier
		hi def link YATE_tag_kind Type
		hi def link YATE_tag_filename Directory
			
		let s:yate_winnr=bufnr("YATE")
		
		setlocal buftype=nofile

		if !exists("s:first_time")
			autocmd BufUnload <buffer> exe 'let s:yate_winnr=-1'

			cal <SID>OnEnterBuffer()

			autocmd BufEnter <buffer> cal <SID>OnEnterBuffer()
			autocmd BufLeave <buffer> cal <SID>OnLeaveBuffer()

			let s:first_time=1
		endif
	else
		cal <SID>OnLeaveBuffer()

		exe ':wincmd p'
		exe ':'.s:yate_winnr.'bd!'
		let s:yate_winnr=-1
	endif
endfun
