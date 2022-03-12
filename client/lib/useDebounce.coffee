import {useState, useEffect} from 'react'

## Based on https://usehooks.com/useDebounce/

export useDebounce = (value, delay) ->
  ## State and setters for debounced value
  [debouncedValue, setDebouncedValue] = useState value

  ## Only re-call effect if value or delay changes.
  ## Allow value to be an array or a single value.
  if Array.isArray value
    deps = [delay].concat value
  else
    deps = [delay, value]

  useEffect ->
    ## Update debounced value after delay
    handler = setTimeout (-> setDebouncedValue value), delay

    ## Cancel the timeout if value changes (also on delay change or unmount).
    ## This is how we prevent debounced value from updating if value is
    ## changed within the delay period. Timeout gets cleared and restarted.
    -> clearTimeout handler
  , deps

  debouncedValue
