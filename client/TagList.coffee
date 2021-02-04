import React from 'react'

export TagList = React.memo ({group, tags, noLink}) ->
  for tag in tags
    label =
      <span className="tag label label-default">
        {tag.key + (if (not tag.value? or tag.value == true) then "" else ":"+tag.value)}
      </span>
    <React.Fragment key={tag.key}>
      {' '}
      {if noLink
        label
      else
        <a href={linkToTag tag, group} className="tagLink">{label}</a>
      }
    </React.Fragment>
TagList.displayName = 'TagList'
