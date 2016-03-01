## http://docs.mathjax.org/en/latest/options/tex2jax.html

window.MathJax =
  extensions: [
    "tex2jax.js"
    "MathEvents.js"
    "MathZoom.js"
    "MathMenu.js"
    "toMathML.js"
    "TeX/noErrors.js"
    "TeX/noUndefined.js"
    "TeX/AMSmath.js"
    "TeX/AMSsymbols.js"
  ]
  jax: [
    "input/TeX"
    "output/HTML-CSS"
  ]
  tex2jax:
    inlineMath: [ ['$','$'], ["\\(","\\)"] ]
    displayMath: [ ['$$','$$'], ["\\[","\\]"] ]
    processEscapes: true
    ignoreClass: 'nojax'
    processClass: 'tex2jax'
  skipStartupTypeset: true
  ## This is a workaround until https://github.com/mathjax/MathJax/issues/1403
  ## gets solved (see https://github.com/mathjax/MathJax/issues/1399)
  AuthorInit: -> MathJax.Ajax.config.root = '/mathjax'

Meteor.startup ->
  $('body').addClass 'nojax'

initialRender = false

ready = ->
  MathJax.Hub?
typeset = ->
  MathJax.Hub.Queue ["Typeset", MathJax.Hub]

$.getScript '/mathjax/MathJax.js', ->
  if initialRender
    typeset()
    initialRender = false  ## not really needed; only used here

@mathjax = ->
  if ready()
    typeset()
    initialRender = false
  else
    initialRender = true  ## do it once MathJax loads

## The following should be called only from within Tracker.autorun.
## It waits until the flush is complete (entire page redrawn?),
## and then calls mathjax() *once*.
todo = false
@automathjax = ->
  todo = true
  Tracker.afterFlush ->
    if todo
      mathjax()
      todo = false
