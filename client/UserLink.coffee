import React from 'react'
import OverlayTrigger from 'react-bootstrap/OverlayTrigger'
import Tooltip from 'react-bootstrap/Tooltip'
import {useTracker} from 'meteor/react-meteor-data'

## Written as a React replacement for lib/users.coffee's `linkToAuthor`
export UserLink = React.memo ({user, username, group, title, subtitle, prefix, placement}) ->
  username ?= user.username
  user ?= useTracker ->
    findUsername username
  , [username]
  group ?= Router.current()?.params?.group ? wildGroup
  link = urlFor 'author',
    group: group
    author: username
  highlight = #useTracker ->
    Router.current()?.route?.getName() == 'author' and
    Router.current()?.params?.author == username
  tooltip = (props) ->
    <Tooltip {...props}>{title}
      {if title?
        {title}
      else if user?
        <>
          <b>Username:</b> {username}
          {if email = user.emails?[0]
            <>
              <br/>
              <b>Email:</b> {email.address}
              {unless email.verified
                " (unverified)"
              }
            </>
          }
          {if user.createdAt?
            <>
              <br/>
              <b>Joined:</b> {formatDateOnly user.createdAt}
            </>
          }
        </>
      else
        <>
          <b>Unknown username:</b> {username}
          <br/>
          This can happen when the user was removed from the group.
        </>
      }
      {if subtitle?
        <>
          <hr/>
          {subtitle}
        </>
      }
    </Tooltip>
  <OverlayTrigger placement={placement} flip overlay={tooltip}>
    <a className="author #{if highlight then 'highlight' else ''}"
     data-username={username} href={link}>
      {prefix}
      {displayUser user}
    </a>
  </OverlayTrigger>
UserLink.displayName = 'UserLink'
