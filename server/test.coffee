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
