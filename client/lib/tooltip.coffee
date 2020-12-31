import {useEffect, useRef} from 'react'

## Helper to call from `onRendered` methods to initialize tooltips.
@tooltipInit = (template = Template.instance()) ->
  template.$('[data-toggle="tooltip"]')
  .tooltip()

## Helper to call to close all tooltips in current template.
@tooltipHide = (template = Template.instance()) ->
  template.$('[data-toggle="tooltip"]')
  .tooltip 'hide'

## Helper to call from template helpers that updates all tooltips in the
## current template, after the helper completes.  Call from helpers that
## define tooltip `title`s.
@tooltipUpdate = (template = Template.instance()) ->
  template.debounced ?= _.debounce ->
    try
      template.$('[data-toggle="tooltip"]')
      .tooltip 'fixTitle'
    catch e
      console.warn e  # e.g. DomRange removed
  , 50
  Meteor.defer template.debounced

###
Hook to maintain Bootstrap 3 tooltips in a React template.
Returns a ref that you should put on your root template.
Or, if you already have such a ref, pass it in instead.
###
export useRefTooltip = (ref = useRef()) ->
  init = useRef true
  useEffect ->
    return unless ref.current?
    tips = $(ref.current).find('[data-toggle="tooltip"]')
    if init.current
      tips.tooltip()
      init.current = false
    else
      tips.tooltip 'fixTitle'
    -> tips.tooltip 'hide'
  ref