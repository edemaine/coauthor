Template.messageImage.onRendered ->
  @autorun @update = =>
    rotate = messageRotate Template.currentData()
    imageTransform @find('.rotateCCW90 img'), rotate - 90
    imageTransform @find('.rotate180 img'), rotate + 180
    imageTransform @find('.rotateCW90 img'), rotate + 90
    ## Couldn't get this full-height hack to work:
    #for a in @findAll 'img'
    #  li = a.parentNode
    #  console.log li.clientHeight
    #  a.style.height = "#{li.clientHeight}px" if li.clientHeight

Template.messageImage.events
  'shown.bs.dropdown .messageImage': (e, t) ->
    t.update()
  'click .rotateCCW90': (e, t) ->
    Meteor.call 'messageUpdate', t.data._id,
      rotate: angle180 (t.data.rotate ? 0) - 90
  'click .rotate180': (e, t) ->
    Meteor.call 'messageUpdate', t.data._id,
      rotate: angle180 (t.data.rotate ? 0) + 180
  'click .rotateCW90': (e, t) ->
    Meteor.call 'messageUpdate', t.data._id,
      rotate: angle180 (t.data.rotate ? 0) + 90

Template.messageImage.helpers
  urlToFile: -> urlToFile @

@imageTransform = (image, rotate) ->
  unless image.width  ## wait for load
    image.onload = -> imageTransform image, rotate
    return
  if rotate
    ## `rotate` is in clockwise degrees
    radians = -rotate * Math.PI / 180
    ## Computation based on https://stackoverflow.com/a/3231438
    width = Math.abs(Math.sin radians) * image.height + Math.abs(Math.cos radians) * image.width
    height = Math.abs(Math.sin radians) * image.width + Math.abs(Math.cos radians) * image.height
    #scale = image.width / width
    ## max-width: 100%
    scale = image.parentNode.getBoundingClientRect().width / width
    return unless scale  ## avoid zero scaling (invisible box)
    scale = 1 if scale > 1
    ## max-height: 100vh
    if height * scale > window.innerHeight
      scale *= window.innerHeight / (height * scale)
    width *= scale
    height *= scale
    image.style.transform = "translate(#{(width - image.width)/2}px, #{(height - image.height)/2}px) scale(#{scale}) rotate(#{rotate}deg)"
    image.parentNode.style.height = "#{height}px"
  else
    image.style.transform = null
    image.parentNode.style.height = null
