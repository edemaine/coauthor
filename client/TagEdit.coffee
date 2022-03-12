import React, {useLayoutEffect, useState} from 'react'
import Dropdown from 'react-bootstrap/Dropdown'

## Given `tag`, component is a big editor for that tag (and its value).
## Given `tags`, component offers to select a tag from that list.
## Either way, `children` gives the contents of the dropdown button
## that brings up the editor.
export TagEdit = React.memo ({tag, tags, onTagEdit, onTagSelect, onTagRemove, className, children}) ->
  [show, setShow] = useState false
  [tagKey, setTagKey] = useState ''
  [tagVal, setTagVal] = useState ''
  useLayoutEffect resetTag = ->
    setTagKey tag?.key ? ''
    setTagVal if tag?.value == true then '' else tag?.value ? ''
    undefined
  , [tag]
  onClose = (e) ->
    e.preventDefault()
    setShow false
    resetTag()

  big = tag?
  <span className="#{if tag? then 'tagEdit' else 'tagNew'} btn-group"
   data-tag={tag?.key}>
    <Dropdown show={show} onToggle={(newShow) -> setShow newShow}>
      <Dropdown.Toggle variant="default" className={className}>
        {children}
      </Dropdown.Toggle>
      <Dropdown.Menu className="tagMenu">
        {if onTagEdit?
          <li className="disabled">
            <a>
              <form className="input-group-sm">
                <input className="tagKey form-control" type="text"
                 placeholder="New Tag..." value={tagKey}
                 onChange={(e) -> setTagKey e.currentTarget.value}/>
                <input className="tagVal form-control" type="text"
                 placeholder="Value" value={tagVal}
                 onChange={(e) -> setTagVal e.currentTarget.value}/>
                <div className={if big then "btn-group" else "input-group-btn"}>
                  <button className="btn btn-success" type="submit" onClick={(e) -> onTagEdit e, tagKey, tagVal, tag?; onClose e}>
                    {if tag?
                      'Update'
                    else
                      <span className="fas fa-plus"/>
                    }
                  </button>
                  {if onTagRemove?
                    <button className="btn btn-danger" onClick={onTagRemove}>
                      Delete
                    </button>
                  }
                  {if big
                    <button className="btn btn-warning" onClick={onClose}>
                      Cancel
                    </button>
                  }
                </div>
              </form>
            </a>
          </li>
        }
        {if onTagEdit? and tags?.length
          <li className="divider" role="separator"/>
        }
        {if tags?.length
          for subtag in tags
            <li key={subtag.key}>
              <Dropdown.Item className="tagSelect" href="#" data-tag={subtag.key} onClick={onTagSelect}>{subtag.key}</Dropdown.Item>
            </li>
        }
      </Dropdown.Menu>
    </Dropdown>
  </span>

TagEdit.displayName = 'TagEdit'
