import React from 'react'

import {linkToTag} from '/lib/tags'

export TagList = React.memo ({group, tags, noLink}) ->
  if noLink
    link = (tag, dom) -> dom
  else
    link = (tag, dom) ->
      <a href={linkToTag tag, group} className="tagLink">{dom}</a>
  for tag in tags
    <React.Fragment key={tag.key}>
      {' '}
      {if tag.value and tag.value != true
        <span className="tag">
          {link {key: tag.key},
            <span className="label label-default label-left">{tag.key}</span>
          }
          {link tag,
            <span className="label label-default label-right">{tag.value}</span>
          }
        </span>
      else
        link tag, <span className="tag label label-default">{tag.key}</span>
      }
    </React.Fragment>
TagList.displayName = 'TagList'
