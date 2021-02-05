import React from 'react'
import Dropdown from 'react-bootstrap/Dropdown'

export TagEdit = React.memo ({addTagRef, onTagNew, onTagAdd, absentTags, tag, children}) ->
  <span className="btn-group">
    <Dropdown>
      <Dropdown.Toggle variant="default"
       className="label label-default" ref={addTagRef}>
         {children}
      </Dropdown.Toggle>
      <Dropdown.Menu className="tagMenu">
        {if onTagNew?
          <li className="disabled">
            <a>
              <form className="input-group input-group-sm">
                <input className="tagAddText form-control" id="tagKey" type="text" 
                  placeholder="New Tag..." 
                  defaultValue={tag?.key ? ""} />
                <input className="tagAddText form-control" id="tagVal" type="text" 
                  placeholder="Value (opt.)" 
                  defaultValue={if not tag?.value or tag?.value == true then "" else tag.value } />
                <div className="input-group-btn">
                  <button className="btn btn-default tagAddNew" type="submit" onClick={onTagNew}>
                    <span className="fas fa-plus"/>
                  </button>
                </div>
              </form>
            </a>
          </li>
        }
        {if onTagNew? and absentTags.length and not tag?
          <li className="divider" role="separator"/>
        }
        {if absentTags.length and not tag?
          <>
            {for tag in absentTags
              <li key={tag.key}>
                <Dropdown.Item className="tagAdd" href="#" data-tag={tag.key} onClick={onTagAdd}>{tag.key}</Dropdown.Item>
              </li>
            }
          </>
        }
      </Dropdown.Menu>
    </Dropdown>
  </span>

TagEdit.displayName = 'TagEdit'
