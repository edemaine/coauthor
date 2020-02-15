import { messageFolded } from '../client/message.coffee'
import { updateUploading } from '../lib/files.coffee'

title = 'Downloading ZIP archive...'

timer = (delay) ->
  new Promise (done) -> Meteor.setTimeout done, delay

untilReady = -> new Promise (done) ->
  Tracker.autorun (computation) ->
    if Router.current().ready()
      done()
      computation.stop()

urlBasename = (url) ->
  file = (new URL url).pathname
  file = file[1+file.lastIndexOf '/'..] if file.includes '/'
  file

files = {}
internalFiles = {}
subthreads = false

savePage = (zip, group, filename) ->
  pageUrl = document.URL
  now = formatDate new Date, '', true # absolute
  updateUploading -> @[title] =
    filename: title
    progress: 0
  html = document.documentElement.outerHTML
  get = []
  ## Fix internal links and images
  for linkType in [pathFor, urlFor]
    ## Links to internal messages
    re = linkType 'message',
      group: group
      message: 'MESSAGE'
    .replace /MESSAGE/, "(#{idRegex})"
    html = html.replace ///(<[aA]\b[^<>]*[hH][rR][eE][fF]\s*=\s*['"])#{re}///g,
      "$1$2.html"
    ## Links to internal groups
    re = linkType 'group',
      group: group
    html = html.replace ///(<[aA]\b[^<>]*[hH][rR][eE][fF]\s*=\s*['"])#{re}(?!/)///g,
      "$1index.html"
  ## Fix other internal links to refer to Coauthor site
  html = html.replace ///(<[aA]\b[^<>]*[hH][rR][eE][fF]\s*=\s*['"])\////g,
    "$1#{Meteor.absoluteUrl()}" # absoluteUrl includes leading /
  ## Files
  mapFile = (id) ->
    return files[id] if files[id]?
    message = findMessage id
    unless message?
      console.warn "Could not find image file #{id}"
      return
    actualFile = findFile message.file
    extension = (/(\.[^.]*)$/.exec actualFile?.filename ? '')?[0] ? ''
    files[id] = "files/#{id}#{extension}"
    get.push
      url: Meteor.absoluteUrl fileUrlPrefix + id
      file: files[id]
    files[id] = "files/#{id}#{extension}"
  html = html.replace ///(<(?:[iI][mM][gG]|[sS][oO][uU][rR][cC][eE])\b[^<>]*[sS][rR][cC]\s*=\s*['"])(?:#{escapeRegExp Meteor.absoluteUrl()[...-1]})?#{escapeRegExp fileUrlPrefix}(#{idRegex})(['"])///g,
    fixFile = (match, left, id, right) ->
      mapped = mapFile id
      return match unless mapped?
      "#{left}#{mapped}#{right}"
  html = html.replace ///(<[aA]\b[^<>]*[hH][rR][eE][fF]\s*=\s*['"])(?:#{escapeRegExp Meteor.absoluteUrl()[...-1]})?#{escapeRegExp fileUrlPrefix}(#{idRegex})(['"])///g, fixFile
  ## Transform tooltips back into titles
  html = html.replace /\btitle=(''|"")\b/ig, ''
  html = html.replace /\bdata-original-title=/g, 'title='
  ## Linked CSS and favicons
  html = html.replace ///(<link[^<>]*\bhref\s*=\s*['"])([^'"<>]*)(['"][^<>]*>)///ig,
    (match, left, url, right) ->
      # Remove crossorigin limits, as we're making the linked file local.
      # Remove integrity hashes, as we modify CSS to use relative paths.
      left = left.replace /\b(crossorigin|integrity)\s*=\s*['"].*?['"]/g, ''
      right = right.replace /\b(crossorigin|integrity)\s*=\s*['"].*?['"]/g, ''
      if google = ///family=(\w+)///.exec url
        file = "#{google[1]}.css"
      else if fontAwesome = ///(fontawesome).*?(v\d+\.\d+\.\d+).*?(\w+.css)///.exec url
        file = fontAwesome[1..3].join '-'
      else
        url = Meteor.absoluteUrl() + url[1..] if url.startsWith '/'
        file = urlBasename url
      css = /rel\s*=\s*['"]stylesheet['"]/i.test match
      file = "css/#{file}" if css
      get.push {url, file, css}
      "#{left}#{file}#{right}"
  ## Download (possibly recursively) linked files
  while job = get.pop()
    {url, file, css} = job
    ## Skip files already in the zip file (e.g. repeated CSS)
    continue if zip.file "#{group}/#{file}"
    try
      response = await fetch url
    catch e
      console.warn "Failed to fetch link '#{url}': #{e}"
      continue
    unless response.ok
      console.warn "Failed to fetch link '#{url}': #{response.status} #{response.statusText}"
      continue
    if css
      css = await response.text()
      css = css.replace /url\(([^()]*)\)/ig, (match, suburl) ->
        suburl = suburl.replace /^['"](.*)['"]/, "$1"
        return match if suburl.startsWith 'data:'
        if suburl.startsWith '/'  # semi-relative URL
          suburl = url[...3+url.indexOf '://'] + suburl
        else if not suburl.includes '://'  # relative URL
          suburl = url[..url.lastIndexOf '/'] + suburl
        subfile = urlBasename suburl
        subfile = "fonts/#{subfile}"
        get.push
          url: suburl
          file: subfile
        # ../ below gets us out of css directory
        "url('../#{subfile}')"
      css = "/* Coauthor downloaded from #{url} */\n#{css}"
      zip.file "#{group}/#{file}", css
    else
      zip.file "#{group}/#{file}", await response.blob()
  ## Remove scripts
  html = html.replace ///<script[^<>]*>.*?</script>///g, ''
  ## Hide interactive buttons
  html = html.replace ///</body>///i, (match) -> """
      <style>
        .group-right-buttons,
        .superButton, .usersButton, .settingsButton, .searchText,
        .rawButton, .historyButton, .editButton, .replaceButton, .actionButton,
        .message-reply-buttons, .emojiButtons,
        .dropdown-toggle .caret, .dropdown-menu,
        .pdfButtons, .pdfStatus, .pdfBox,
        .foldButton, #{if subthreads then '' else '.focusButton,'}
        .footer { display: none !important }
      </style>
      #{match}
    """
  ## Link to original
  html = """
    <!DOCTYPE html>
    <!-- Coauthor downloaded from #{pageUrl} on #{now} -->
    #{html}
  """
  html = html.replace /<a\s+id\s*=\s*['"]archive['"]>/i,
    """<a id="archive" title="Live version of this page, archived #{now}" style="font-size: small" href="#{pageUrl}">#{pageUrl}</a>"""
  #console.log html
  zip.file "#{group}/#{filename}", html

export downloadGroup = (group) ->
  unless group?
    return console.error 'No group specified for download'
  files = {}
  internalFiles = {}
  JSZip = (await import('jszip')).default
  zip = new JSZip
  ## Group page
  await untilReady()
  console.assert Router.current().route.getName() == 'group',
    "User navigated away from group"
  savePage zip, group, 'index.html'
  #return
  ## Thread pages
  ids = rootMessages(group).map (msg) -> msg._id
  for id, count in ids
    updateUploading -> @[title].progress = Math.floor 100 * count / ids.length
    Router.go 'message',
      group: group
      message: id
    # Some positive waiting is necessary for router to activate and page to
    # render.  Wait for a fairly positive value to avoid pummeling the server.
    await timer 5
    await untilReady()
    await timer 5
    messageFolded.clear()
    await timer 500
    savePage zip, group, "#{id}.html"
  updateUploading -> @[title].progress = 100
  ## Go back to group page
  Router.go 'group',
    group: group
  ## Download ZIP
  blob = await zip.generateAsync type: 'blob'
  (await import('file-saver')).saveAs blob, "#{group}.zip"
  updateUploading -> delete @[title]
