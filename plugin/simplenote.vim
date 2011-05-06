"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" WebPage: http://github.com/mrtazz/simplenote.vim
" License: MIT
" Usage:
"
"
"

if &cp || (exists('g:loaded_simplenote_vim') && g:loaded_simplenote_vim)
  finish
endif
let g:loaded_simplenote_vim = 1

" check for python
if !has("python")
  echoerr "Simplenote: Plugin needs vim to be compiled with python support."
  finish
endif

" user auth settings
let s:user = ""
let s:password = ""

let s:user = g:SimpleNoteUserName
let s:password = g:SimpleNotePassword

if (s:user == "") || (s:password == "")
  echoerr "No valid username or password."
  finish
endif

"
" Helper functions
"

" Everything is displayed in a scratch buffer named SimpleNote
let g:simplenote_scratch_buffer = 'SimpleNote'

" Function that opens or navigates to the scratch buffer.
function! s:ScratchBufferOpen(name)

    let scr_bufnum = bufnr(a:name)
    if scr_bufnum == -1
        exe "new " . a:name
    else
        let scr_winnum = bufwinnr(scr_bufnum)
        if scr_winnum != -1
            if winnr() != scr_winnum
                exe scr_winnum . "wincmd w"
            endif
        else
            exe "split +buffer" . scr_bufnum
        endif
    endif
    call ScratchBuffer()
endfunction

" After opening the scratch buffer, this sets some properties for it.
function! ScratchBuffer()
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal buflisted
    setlocal cursorline
    setlocal filetype=txt
endfunction


"
" python functions
"

python << ENDPYTHON
import vim
import urllib2
import base64
import json

AUTH_URL = 'https://simple-note.appspot.com/api/login'
DATA_URL = 'https://simple-note.appspot.com/api2/data/'
INDX_URL = 'https://simple-note.appspot.com/api2/index?'
DEFAULT_SCRATCH_NAME = vim.eval("g:simplenote_scratch_buffer")

def scratch_buffer(sb_name = DEFAULT_SCRATCH_NAME):
    """ Opens a scratch buffer from python """
    vim.command("call s:ScratchBufferOpen('%s')" % sb_name)

#
# @brief function to get simplenote auth token
#
# @param user -> simplenote email address
# @param password -> simplenote password
#
# @return simplenote API token
#
def simple_note_auth(user, password):
    auth_params = "email=%s&password=%s" % (user, password)
    values = base64.encodestring(auth_params)
    request = urllib2.Request(AUTH_URL, values)
    try:
        token = urllib2.urlopen(request).read()
    except IOError, e: # no connection exception
        token = None
    return token

#
# @brief function to get a specific note
#
# @param user -> simplenote username
# @param token -> simplenote API token
# @param noteid -> ID of the note to get
#
# @return content of the desired note

def get_note(user, token, noteid):
    # request note
    params = '%s?auth=%s&email=%s' % (noteid, token, user)
    request = urllib2.Request(DATA_URL+params)
    try:
        response = urllib2.urlopen(request)
    except IOError, e:
        return None
    note = json.loads(response.read())
    return note["content"]

#
# @brief function to update a specific note
#
# @param user -> simplenote username
# @param token -> simplenote API token
# @param noteid -> noteid to update
# @param content -> content of the note to update
#
# @return
#
def update_note(user, token, noteid, content):
    params = '%s?auth=%s&email=%s' % (noteid, token, user)
    noteobject = {}
    noteobject["content"] = content
    note = json.dumps(noteobject)
    values = urllib.urlencode(note)
    request = urllib2.Request(DATA_URL+params, values)
    try:
        response = urllib2.urlopen(request)
    except IOError, e:
        return False
    return True

#
# @brief function to get the note list
#
# @param user -> simplenote username
# @param token -> simplenote API token
#
# @return list of note titles and success status
#
def get_note_list(user, token):
    params = 'auth=%s&email=%s' % (token, user)
    request = urllib2.Request(INDX_URL+params)
    status = 0
    try:
      response = json.loads(urllib2.urlopen(request).read())
    except IOError, e:
      status = -1
      response = { "data" : [] }
    ret = []
    # parse data fields in response
    for d in response["data"]:
        ret.append(d["key"])

    return ret, status

# retrieve a token to interact with the API
SN_USER = vim.eval("s:user")
SN_TOKEN = simple_note_auth(SN_USER, vim.eval("s:password"))

ENDPYTHON

"
" interface functions
"

function! s:SimpleNote(param)
python << EOF
param = vim.eval("a:param")
if param == "-l":
    print "List notes"
    # Initialize the scratch buffer
    scratch_buffer()
    del vim.current.buffer[:]
    buffer = vim.current.buffer
    notes, status = get_note_list(SN_USER, SN_TOKEN)
    if status == 0:
        for n in notes:
            print "appending %s to buffer" % n
            buffer.append(str(n))
            print "appended"
    else:
        print "Error: Unable to connect to server."
    # map <CR> to call get_note()
    vim.command("map <buffer> <CR> <Esc>:call get_note()<CR>")

elif param == "-d":
    print "Delete note"
elif param == "-u":
    print "Update note"
else:
    print "Unknown argument"

EOF
endfunction


" set the simplenote command
command! -nargs=1 SimpleNote :call <SID>SimpleNote(<f-args>)
