## This server-side verison loads all highlight.js languages immediately.
## See client/lib/highlight.coffee for the more interesting client-side version.

import hljs from 'highlight.js'  # full library

@highlight = (text, lang) ->
  return '' unless lang
  if hljs.getLanguage lang
    try
      return hljs.highlight text,
        language: lang
        ignoreIllegals: true
      .value
  ''  ## markdown-it's default formatting
