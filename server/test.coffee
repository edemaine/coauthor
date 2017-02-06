if Groups.find().count() == 0
  Groups.insert
    name: 'compgeom'
    created: new Date
  Groups.insert
    name: '6.890'
    created: new Date
  Groups.insert
    name: 'test'
    created: new Date
    anonymous: ['read', 'post', 'edit']

## This code would add version numbers to MessageDiff objects, instead of
## relying on sorting by 'updated'...  (code not finished)
#if true
#  Messages.find().forEach (msg) ->
#    olds = MessagesDiff.find
#      id: msg._id
#    ,
#      sort: [
#    .fetch()
#    console.log olds
