import React, {useEffect, useRef, useState} from 'react'
import {useTracker} from 'meteor/react-meteor-data'

import {ErrorBoundary} from './ErrorBoundary'

heic = null  # will become import of 'libheif-web'

export MessageHEIC = ({file}) ->
  <ErrorBoundary>
    <WrappedMessageHEIC file={file}/>
  </ErrorBoundary>
MessageHEIC.displayName = 'MessageHEIC'

WrappedMessageHEIC = React.memo ({file}) ->
  [pngBlob, setPngBlob] = useState()
  [url, setUrl] = useState()

  useTracker =>
    ## Load libheif-web
    unless heic?
      Session.set 'heicLoading', true
      Session.get 'heicLoading'  # rerun tracker once libheif-web loaded
      return import('libheif-web').then (imported) ->
        heic = window.heic = imported
        heic.useUrl '/libheif.min.js'
        Session.set 'heicLoading', false
    ## Load HEIC file
    fileData = findFile file
    return unless fileData?
    fetch urlToInternalFile file
    .then (response) => response.blob()
    .then (blob) =>
      heic.convertHeif blob, file.filename + '.png', 'image/png'
    .then (png) => setPngBlob png
  , [file]
  useEffect =>
    return unless pngBlob?
    url = setUrl URL.createObjectURL pngBlob
    => URL.revokeObjectURL url
  , [pngBlob]

  if url
    <img src={url}/>
  else
    null
WrappedMessageHEIC.displayName = 'WrappedMessageHEIC'
