# https://github.com/edemaine/cocreate/blob/main/client/lib/platform.coffee
if navigator?.platform?.startsWith? 'Mac'
  Ctrl = 'Command'
  Alt = 'Option'
else
  Ctrl = 'Ctrl'
  Alt = 'Alt'
export {Ctrl, Alt}
