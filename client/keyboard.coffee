document.addEventListener 'keydown', (e) ->
  switch e.key
    when 'Escape', 'Esc'
      Modal.hide()  # leave modal if any currently shown
    when 's', 'S'
      return if e.target.tagName in ['INPUT', 'TEXTAREA']
      return if e.ctrlKey or e.altKey or e.metaKey
      e.preventDefault()
      e.stopPropagation()
      Session.set 'super', not Session.get 'super'  # toggle Become Superuser
