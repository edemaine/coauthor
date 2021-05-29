## Coop protocol
window.addEventListener 'message', (e) ->
  return unless e.data?.coop
  if typeof e.data.theme?.dark == 'boolean'
    theme = if e.data.theme.dark then 'dark' else 'light'
    Session.set 'coop:themeGlobal', theme
    Session.set 'coop:themeEditor', theme
    Session.set 'coop:themeDocument', theme

## window.opener can be null, but window.parent defaults to window
parent = window.opener ? window.parent
if parent? and parent != window
  parent.postMessage
    coop: 1
    status: 'ready'
  , '*'
