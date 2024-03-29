import React from 'react'

import {linkToTag} from '/lib/tags'

export TagList = React.memo ({group, tag, tags, variant, noLink}) ->
  variant ?= 'default'
  if noLink
    link = (tag, dom) -> dom
  else
    link = (tag, dom) -> # eslint-disable-line coffee/display-name
      <a href={linkToTag tag, group} className="tagLink">{dom}</a>
  if tag?
    tags = [tag]
    space = ''  # no leading space for tag
  else
    space = ' ' # space before first and every tag
  for tag in tags ? [tag]
    <React.Fragment key={tag.key}>
      {space}
      {if tag.value and tag.value != true
        <span className="tag">
          {link {key: tag.key},
            <span className="label label-#{variant} label-left">{tag.key}</span>
          }
          {link tag,
            <span className="label label-#{variant} label-right">{tag.value}</span>
          }
        </span>
      else
        link tag, <span className="tag label label-#{variant}">{tag.key}</span>
      }
    </React.Fragment>
TagList.displayName = 'TagList'
