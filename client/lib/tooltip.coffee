import React from 'react'
import OverlayTrigger from 'react-bootstrap/OverlayTrigger'
import Tooltip from 'react-bootstrap/Tooltip'

export TextTooltip = React.memo ({title, children, ...config}) ->
  <OverlayTrigger flip {...config}
   overlay={(props) -> <Tooltip {...props}>{title}</Tooltip>}>
    {children}
  </OverlayTrigger>
TextTooltip.displayName = 'TextTooltip'
