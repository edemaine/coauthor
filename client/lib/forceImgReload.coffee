## Based on http://stackoverflow.com/questions/1077041/refresh-image-with-a-new-one-at-the-same-url#answer-22429796
## solution 4 by Doin

blankImg = '/updating.png'

@forceImgReload = (src) ->
  init = 0
  tags = null
  loadCallback = (e) ->
    unless init
      tags = $("img[src$='#{src}'], video source[src$='#{src}']")
      tags.attr 'src', blankImg
      init = true
      iframe.contentWindow.location.reload true
    else
      tags.attr 'src', src
      iframe.contentWindow.stop?()
      iframe.parentNode.removeChild iframe

  iframe = document.createElement 'iframe'
  iframe.style.display = 'none'
  document.body.appendChild iframe
  iframe.addEventListener 'load', loadCallback, false
  iframe.addEventListener 'error', loadCallback, false
  iframe.src = src
