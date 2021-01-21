import React, {Suspense, useMemo, useRef} from 'react'
import {useTracker} from 'meteor/react-meteor-data'
Typeahead = React.lazy -> import('react-bootstrap-typeahead/es/components/Typeahead')

import {ErrorBoundary} from './ErrorBoundary'

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
    .fetch()
  , []
  sorted = useMemo ->
    if omit?
      omitted = (user for user in users when user.username not of omit)
    else
      omitted = users
    _.sortBy omitted, userSortKey
  , [users, omit]
  ref = useRef()

  onChange = (selected) ->
    if selected.length
      onSelect selected[0]
      ref.current.clear()

  <Suspense fallback={
    <input type="text" className="form-control disabled"
     placeholder={placeholder}/>
  }>
    <Typeahead ref={ref} placeholder={placeholder} id="userInput#{count}"
     options={sorted} labelKey={labelKey} align="left" flip
     onChange={onChange}/>
  </Suspense>
WrappedUserInput.displayName = 'WrappedUserInput'

labelKey = (user) ->
  key = "@#{user.username}"
  if user.profile?.fullname
    #key += " #{user.profile.fullname}"
    key = "#{user.profile.fullname} #{key}"
  key
