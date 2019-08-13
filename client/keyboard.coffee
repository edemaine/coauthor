document.addEventListener 'keydown', (e) ->
  switch e.key
    when 'Escape', 'Esc'
      Modal.hide()  # leave modal if any currently shown
