## Browser policy to allow many external sources, but *not* frames.
#BrowserPolicy.content.allowOriginForAll 'http://meteor.local'
BrowserPolicy.content.allowImageOrigin '*'
BrowserPolicy.content.allowMediaOrigin '*'
BrowserPolicy.content.allowFontOrigin '*'
BrowserPolicy.content.allowStyleOrigin '*'
BrowserPolicy.content.allowConnectOrigin '*'

## Allow blob source for images, as needed by pdf.js
BrowserPolicy.content.allowImageOrigin 'blob:'
