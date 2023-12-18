import {currentPDF} from './MessagePDF'

export ignoreKey = (e) ->
  e.target.tagName in ['INPUT', 'TEXTAREA'] or
  e.target.className.includes('CodeMirror') or
  e.ctrlKey or e.altKey or e.metaKey

document.addEventListener 'keydown', (e) ->
  return if ignoreKey e
  switch e.key
    when 'Escape', 'Esc'
      Modal.hide()  # leave modal if any currently shown
    when 's', 'S'
      e.preventDefault()
      e.stopPropagation()
      Session.set 'super', not Session.get 'super'  # toggle Become Superuser
    when '-'
      currentPDF?.current -1
    when '+', '='
      currentPDF?.current +1
