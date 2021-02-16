import React from 'react'

export class ErrorBoundary extends React.Component
  constructor: (props) ->
    super props
    @state = error: null
  @getDerivedStateFromError: (error) ->
    error: error
  render: ->
    if @state.error
      <div className="alert alert-danger" role="alert">
        <p>Error while rendering this component:</p>
        <blockquote style={marginTop: '5px', marginBottom: '5px'}>
          {@state.error.toString()}
        </blockquote>
        <p>Please <a target="_blank" rel="noreferrer" href="https://github.com/edemaine/coauthor/issues">report this bug</a> along with what caused it and the error messages and trace in the <a target="_blank" rel="noreferrer" href="https://javascript.info/devtools">developer console</a>.</p>
      </div>
    else
      @props.children
