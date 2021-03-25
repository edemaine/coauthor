###
Maintain a list (and count) of unsaved (unsafe) message IDs.
When there are unsaved message IDs, trigger page unload warning
and prevent pushed server migration (until safe again, though that's unlikely).
###

import {Reload} from 'meteor/reload'

## Has the server migrated to a new version?  If so, a Date of when.
export migrateWant = new ReactiveVar false

## If migrateWant is true, this will be a callback to reload the page.
export migrateNow = null

unsafeMap = {}
unsafeCount = 0

export setMigrateSafe = (id, isSafe) ->
  return if isSafe == not unsafeMap[id]
  ## The safe status of this ID changed.
  if isSafe  ## ID now safe
    delete unsafeMap[id]
    unsafeCount--
    if unsafeCount == 0  ## Everything now safe
      window.removeEventListener 'beforeunload', beforeUnloadListener
      if migrateWant.get()
        ## Migrate if we stay safe for a second
        setTimeout ->
          migrateNow() if unsafeCount == 0
        , 1000
  else  ## ID now unsafe
    if unsafeCount == 0  ## First unsafe ID
      window.addEventListener 'beforeunload', beforeUnloadListener
    unsafeMap[id] = true
    unsafeCount++

## See https://github.com/meteor/meteor/blob/master/packages/reload/reload.js
Reload._onMigrate 'coauthor', (retry) ->
  if unsafeCount
    migrateNow = retry
    migrateWant.set true
  ## Return format: [ready, optionalState]
  ## Return ready == false when unsafeCount != 0 to stop migration
  [not unsafeCount]

beforeUnloadListener = (e) ->
  e.preventDefault()
  e.returnValue = "#{unsafeCount} messages (#{(id for id of unsafeMap).join ', '}) have unsaved changes, which will be lost if you close this page."
