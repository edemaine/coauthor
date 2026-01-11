import React, {Suspense, useEffect, useMemo, useRef} from 'react'
import {useTracker} from 'meteor/react-meteor-data'
Typeahead = React.lazy -> import('react-bootstrap-typeahead/es/components/Typeahead')

import {ErrorBoundary} from './ErrorBoundary'
import {sortUsers} from '/lib/users'

import 'react-bootstrap-typeahead/css/Typeahead.css'

userInputCount = 0

export UserInput = React.memo (props) ->
  <ErrorBoundary>
    <WrappedUserInput {...props}/>
  </ErrorBoundary>
UserInput.displayName = 'UserInput'

export WrappedUserInput = React.memo ({group, omit, placeholder, onSelect}) ->
  count = useMemo ->
    userInputCount++
  , []
  users = useTracker ->
    Meteor.users.find
      username: $in: groupMembers group
    ,
      fields:
        username: true
        profile: true
    .map (user) =>
      user.label = "@#{user.username}"
      if user.profile?.fullname
        #key += " #{user.profile.fullname}"
        user.label = "#{user.profile.fullname} #{user.label}"
      user
  , []
  sorted = useMemo ->
    if omit?
      omitted = (user for user in users when not omit user)
    else
      omitted = users
    sortUsers omitted
  , [users, omit]
  amSuper = useTracker ->
    canSuper()
  , []
  ref = useRef()

  ## When the input had focus, and user leaves and then refocuses the window,
  ## the input gets a focus event, which triggers opening the menu.
  ## This can be bad when clicking into the window:
  ## it's easy to accidentally select a menu item in the same click
  ## (if it happens to be where the menu would show).
  ## So we track whether the window just got focus, and if so,
  ## hide the menu on input focus.
  windowJustFocused = useRef false
  useEffect =>
    handleFocus = =>
      windowJustFocused.current = true
      setTimeout =>
        windowJustFocused.current = false
      , 0
    window.addEventListener 'focus', handleFocus
    => window.removeEventListener 'focus', handleFocus
  , []

  onChange = (selected) ->
    if selected.length
      if selected[0].customOption
        onSelect username: selected[0].label.trim()
      else
        onSelect selected[0]
      ref.current.clear()

  <Suspense fallback={
    <input type="text" className="form-control disabled"
     placeholder={placeholder}/>
  }>
    <Typeahead ref={ref} placeholder={placeholder} id="userInput#{count}"
     options={sorted} labelKey="label" align="left" flip
     allowNew={allowNew if amSuper}
     onFocus={=> if windowJustFocused.current then ref.current?.hideMenu()}
     onChange={onChange}/>
  </Suspense>
WrappedUserInput.displayName = 'WrappedUserInput'

allowNew = (results, {text}) ->
  text = text.trim()
  text and not results.some (user) => user.username == text
