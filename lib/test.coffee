if Groups.find().count() == 0 and Meteor.isServer
  Groups.insert
    name: 'compgeom'
  Groups.insert
    name: '6.890'
