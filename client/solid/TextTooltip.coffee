import {splitProps} from 'solid-js'
import {OverlayTrigger, Tooltip} from 'solid-bootstrap'

export TextTooltip = (props) ->
  [props, config] = splitProps props, ['title', 'children']
  <OverlayTrigger flip {...config}
   overlay={<Tooltip>{props.title}</Tooltip>}>
    {props.children}
  </OverlayTrigger>
