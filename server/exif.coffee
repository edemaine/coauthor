ExifParser = require 'exif-parser'

## "The exif section of a jpeg file has a maximum size of 65535 bytes
## and the section seems to always occur within the first 100 bytes of
## the file. So it is safe to only fetch the first 65635 bytes of a
## jpeg file and pass those to the parser."
## [https://github.com/bwindels/exif-parser]
readSize = 100 + 65535

## Date tags from exif-parser.  Rewrite these dates into ISO 8601 strings.
dateTags = ['ModifyDate', 'DateTimeOriginal', 'CreateDate']

Files.find
  contentType: 'image/jpeg'
  'metadata.exif': $exists: false
  'metadata._Resumable': $exists: false
  length: $gt: 0
.observe
  added: (file) ->
    #console.log Files.findOneStream
    #  _id: file._id
    stream = Files.findOneStream
      _id: file._id
    , range:
        start: 0
        end: readSize
    chunks = []
    stream.on 'data', (chunk) -> chunks.push chunk
    stream.on 'end', Meteor.bindEnvironment ->
      buffer = Buffer.concat chunks
      meta = ExifParser.create(buffer).parse()
      ## `imageSize` is set to actual image width and height when seeing the
      ## stream, but given that we only look at the initial `readSize` bytes,
      ## we may not see that.  Use `ExifImageWidth` and `ExifImageHeight`
      ## in this case (which generally seems to be accurate).
      if not meta.imageSize? and \
         meta.tags.ExifImageWidth and meta.tags.ExifImageHeight
        meta.imageSize =
          width: meta.tags.ExifImageWidth
          height: meta.tags.ExifImageHeight
      exif = meta.tags
      ## Rewrite dates into ISO 8601 strings.
      for dateTag in dateTags
        if dateTag of exif
          date = new Date 1000*exif[dateTag]
          iso = date.toISOString()
          if iso[iso.length-1] == 'Z'  ## should be, if EXIF format
            iso = iso[...iso.length-1]
          if iso[iso.length-4..] == '.000'  ## should be, if EXIF format
            iso = iso[...iso.length-4]
          exif[dateTag] = iso
      settings =
        'metadata.exif': exif  ## {} if no EXIF data
      if meta.imageSize
        settings['metadata.width'] = meta.imageSize.width
        settings['metadata.height'] = meta.imageSize.height
      Files.update
        _id: file._id
      , $set: settings
