
blankImg = '/updating.png'

export forceImgReload = (src) ->
  tags = document.querySelectorAll \
    "img[src$='#{src}'], video source[src$='#{src}']"
  ## If no tags, don't bother reloading (e.g. file isn't an image or video)
  return unless tags.length
  ## Wait for all <img> tags to switch to blank image.
  await Promise.all (
    for tag in tags
      do (tag) ->
        new Promise (done) ->
          tag.setAttribute 'src', blankImg
          tag.onload = done
          tag.onerror = done
        .finally ->
          tag.onload = undefined
          tag.onerror = undefined
  )

  ## fetch method seems to work on all browsers but Firefox
  ## [https://bugzilla.mozilla.org/show_bug.cgi?id=1719583]
  unless /Firefox\//.test navigator.userAgent
    response = await fetch src, cache: 'reload'
    await response.blob()
    tag.setAttribute 'src', src for tag in tags
    return

  ## iframe method based on https://stackoverflow.com/a/22429796 by Doin
  first = true
  cleanup = (abort) ->
    iframe.contentWindow.stop?()
    iframe.parentNode.removeChild iframe
  onLoad = (e) ->
    if first
      first = false
      ## First load of iframe: Force reload
      iframe.contentWindow.location.reload true
    else
      ## Second load of iframe triggered from reload: restore references.
      cleanup()
      setTimeout ->
        tag.setAttribute 'src', src for tag in tags
      , 0  # needs to be ~2000 for Chrome

  iframe = document.createElement 'iframe'
  ## Forbid <script> tags or other malicious content,
  ## but allow file to realize it is same origin so that reload above works.
  iframe.sandbox = 'allow-same-origin'
  iframe.style.display = 'none'
  document.body.appendChild iframe
  iframe.addEventListener 'load', onLoad, false
  iframe.addEventListener 'error', onLoad, false
  iframe.src = src
