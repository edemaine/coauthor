import {
  messageFolded
  messageFoldHandler
  naturallyFolded
} from './message.coffee'

Template.readMessage.onRendered ->
  ## Fold naturally folded (minimized and deleted) messages
  ## by default on initial load.
  messageFolded.set @data._id, true if natural = naturallyFolded @data
  @autorun ->
    ## Check for change in naturally folded state.
    data = Template.currentData()
    return unless data._id
    if natural != naturallyFolded data
      messageFolded.set data._id, natural = naturallyFolded data
    mathjax()

Template.readMessage.helpers
  readChildren: -> @readChildren
  pdf: ->
    return if "pdf" != fileType @file
    url: urlToFile @

Template.readMessage.events
  'click .foldButton': messageFoldHandler
