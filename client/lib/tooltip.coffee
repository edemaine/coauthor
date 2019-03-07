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
    template.$('[data-toggle="tooltip"]')
    .tooltip 'fixTitle'
  , 50
  Meteor.defer template.debounced
