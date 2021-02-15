import React from 'react'
import OverlayTrigger from 'react-bootstrap/OverlayTrigger'
import Tooltip from 'react-bootstrap/Tooltip'

export TextTooltip = React.memo ({title, placement, children}) ->
  <OverlayTrigger placement={placement} flip
   overlay={(props) -> <Tooltip {...props}>{title}</Tooltip>}>
    {children}
  </OverlayTrigger>
TextTooltip.displayName = 'TextTooltip'
