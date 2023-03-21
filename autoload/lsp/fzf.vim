vim9script

import './options.vim' as opt
import './util.vim'

# Display items use fzf
export def ShowLocationsByFzf(lspserver: dict<any>, localtions: list<dict<any>>, label: string)
  # create a location list with the location of the references
  var contents: list<string> = []
  for loc in localtions
    var [uri, range] = util.LspLocationParse(loc)
    var fname: string = util.LspUriToFile(uri)
    var bnr: number = fname->bufnr()
    if bnr == -1
      bnr = fname->bufadd()
    endif
    if !bnr->bufloaded()
      bnr->bufload()
    endif
    var text: string = bnr->getbufline(range.start.line + 1)[0]->trim("\t ", 1)
    var content = LspToFzf(fname, 
                           loc.range.start.line + 1, 
                           util.GetLineByteFromPos(bnr, loc.range.start) + 1, 
                           text)
    contents->add(content)
  endfor

  var opt_preview = fzf#vim#with_preview('up:+{2}-/2')

  var options = [
    '--ansi',
    '--delimiter', ':',
    '--keep-right',
    '--prompt', label .. '> ',
    '--expect', 'ctrl-x,ctrl-v',
    '--bind', 'alt-a:select-all,alt-d:deselect-all', '--multi',
  ]

  options += opt_preview['options']

  var wrap = fzf#wrap({'source': contents, 'options': options})
  wrap['sink*'] = Sink
  fzf#run(wrap)

enddef

def LspToFzf(fname: string, row: number, col: number, text: string): string
  var ffname = fnamemodify(fname, ':~:.')
  var content: string = ffname .. ':' .. row .. ':' .. col .. ': ' .. text 
  return content
enddef

def FzfToLsp(fzfStr: string): dict<any>
  var elems = split(fzfStr, ':')  

  var uri = util.LspFileToUri(elems[0])
  var row = str2nr(elems[1], 10) - 1
  var col = str2nr(elems[2], 10) - 1

  var position = {'line': row, 'character': col}
  var range = {'start': position, 'end': position}

  return {'uri': uri, 'range': range}  
enddef

def FzfToQlistItem(fzfStr: string): dict<any>
  var elems = split(fzfStr, ':')  
  var fname = elems[0]
  var row = str2nr(elems[1], 10)
  var col = str2nr(elems[2], 10)
  var text = elems[3]
  return {filename: fname, lnum: row, col: col, text: text}
enddef

def Sink(entries: list<string>)
  if entries->len() < 2 
    return
  endif
  var mods = ActionToCmdmods(entries[0])
  if entries->len() == 2
    var location = FzfToLsp(entries[1])
    util.JumpToLspLocation(location, mods)
    return
  endif

  var localtions = entries[1 :]

  var qflist: list<dict<any>> = []
  for l in localtions
    var item = FzfToQlistItem(l)
    qflist->add(item)
  endfor

  var save_winid = win_getid()
  setloclist(0, [], ' ', {title: 'Loclist', items: qflist})
  exe $'{mods} lopen'
  if !opt.lspOptions.keepFocusInReferences
    save_winid->win_gotoid()
  endif

enddef

def ActionToCmdmods(action: string): string
    if action == "ctrl-v"
        return "vertical"
    elseif action == "ctrl-x"
        return "horizontal"
    endif
    return ""
enddef

# vim: tabstop=8 shiftwidth=2 softtabstop=2
