import {splitProps} from 'solid-js'
#import {OverlayTrigger, Tooltip} from 'solid-bootstrap'
import OverlayTrigger from 'solid-bootstrap/esm/OverlayTrigger'
import Tooltip from 'solid-bootstrap/esm/Tooltip'

export TextTooltip = (props) ->
  [props, config] = splitProps props, ['title', 'children']
  <OverlayTrigger flip {...config}
   overlay={<Tooltip>{props.title}</Tooltip>}>
    {props.children}
  </OverlayTrigger>
