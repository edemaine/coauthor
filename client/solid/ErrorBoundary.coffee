import {ErrorBoundary as SolidErrorBoundary} from 'solid-js'

export ErrorBoundary = (props) ->
  <SolidErrorBoundary fallback={(error) ->
    <div className="alert alert-danger" role="alert">
      <p>Error while rendering this component:</p>
      <blockquote style={marginTop: '5px', marginBottom: '5px'}>
        {error.toString()}
      </blockquote>
      <p>Please <a target="_blank" rel="noreferrer" href="https://github.com/edemaine/coauthor/issues">report this bug</a> along with what caused it and the error messages and trace in the <a target="_blank" rel="noreferrer" href="https://javascript.info/devtools">developer console</a>.</p>
    </div>
  }>
    {props.children}
  </SolidErrorBoundary>
