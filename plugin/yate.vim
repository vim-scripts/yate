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
" Description:	This plugin is trying to make search in tags more convenient.
" 				It holds query and search result in one buffer for faster jump to 
" 				desired tag.
"
" Installation:	Just drop this file in your plugin directory.
"
" Usage:		Command :YATE toggles visibility of search buffer.
" 				Parameter g:YATE_window_height sets height of search buffer.
"
" 				To get list of matching tags set cursor on string containing expression
" 				to search (in YATE buffer) then press <Tab> or <Enter>, never mind if you are in normal 
" 				or insert mode.
"
" 				To open tag location set cursor on string with desired tag and
" 				press <Enter> or double click left mouse button on this string, 
" 				never mind if you are in normal or insert nmode.
" 				To open tag in new tab press <Ctrl-Enter>, in new horizontal
" 				splitted buffer <Shift-Enter>, in new vertical splitted buffer 
" 				<Ctrl-Shift-Enter>.
"
" Version:		0.9
"
" TODO:			Custom mapping;
" 				Real-time autocomplit;
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

command! -bang YATE :call <SID>ToggleTagExplorerBuffer()

fun <SID>GotoTag(open_command)
	let str=getline(".")

	if !exists("s:tags_list") || !len(s:tags_list) || match(str,"^.*|.*|.*|.*$")
		call <SID>GenerateTagsList()
		return
	endif

	let index=str2nr(str)
	
	exe ':wincmd p'
	exe ':'.s:yate_winnr.'bd!'
	let s:yate_winnr=-1

	if !&modified
		exe ':'.a:open_command.' '.s:tags_list[index]['filename']
		exe substitute(s:tags_list[index]['cmd'],"\*","\\\\*","g")
		" Without it you should press Enter once again some times.
		exe 'normal Q'
	else
		throw "No write since last change."
	endif
endfun

fun <SID>AutoCompleteString(str)
	if !exists("s:tags_list") || !len(s:tags_list)
		return
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

	if !exists("s:tags_list") || !len(s:tags_list)
		return
	endif
	
	cal append(0,s:user_line)
	exe 'normal dd$'

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

	let counter=0
	for i in s:tags_list
		let str=counter."\t| ".i["name"]
		for j in range(strlen(i["name"]),lname)
			let str=str.' '
		endfor
		let str=str.'| '.i["kind"]
		for j in range(strlen(i["kind"]),lkind)
			let str=str.' '
		endfor
		let str=str.'| '.i["filename"]
		
		cal append(line("$"),str)

		let counter=counter+1
	endfor
endfun

fun <SID>GenerateTagsList()
	" get tags list
	let s:user_line=getline('.')
	let s:tags_list=taglist(s:user_line)

	let s:user_line=<SID>AutoCompleteString(s:user_line)
	cal <SID>PrintTagsList()
endfun

fun! <SID>ToggleTagExplorerBuffer()
	let  firstTime=!exists("s:yate_winnr")
	if firstTime || s:yate_winnr==-1

		exe "bo".g:YATE_window_height."sp YATE"
		cal <SID>PrintTagsList()

		exe "verbose inoremap <silent> <buffer> <Tab> <C-O>:cal <SID>GenerateTagsList()<CR>"

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

		" color output
		syn match YATE_tag_kind # \w* #
		syn match YATE_tag_number #^\d*#
		syn region YATE_tag_name matchgroup=Macro start=/\t|/ end='|'
		syn region YATE_tag_filename matchgroup=Macro start='|' end=/$/

		hi def link YATE_tag_name Identifier
		hi def link YATE_tag_number Number
		hi def link YATE_tag_kind Type
		hi def link YATE_tag_filename Directory

		let s:yate_winnr=bufnr("YATE")

		if firstTime
			setlocal buftype=nofile
		endif
	else
		exe ':wincmd p'
		exe ':'.s:yate_winnr.'bd!'
		let s:yate_winnr=-1
	endif
endfun
