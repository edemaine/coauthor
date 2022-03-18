export prefersReducedMotion = ->
  window.matchMedia '(prefers-reduced-motion: reduce)'
  .matches

## String to pass into `behavior` option for `Element.scroll`.
## https://developer.mozilla.org/en-US/docs/Web/API/Element/scroll
export scrollBehavior = ->
  if prefersReducedMotion()
    'instant'
  else
    'smooth'
