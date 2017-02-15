Mongo.Collection.prototype.insertMany = (docs) ->
  if @_isRemoteCollection()
    throw new Error "insertMany supported only on server"
  unless docs
    throw new Error "insertMany requires an argument"
  ## Shallow-copy the documents in case we generate IDs
  docs = (_.extend {}, doc for doc in docs)
  for doc in docs
    if doc._id?
      if not doc._id or not (typeof doc._id == 'string' or doc._id instanceof Mongo.ObjectID)
        throw new Error "Meteor requires document _id fields to be non-empty strings or ObjectIDs"
    else
      doc._id = @_makeNewID()
  @rawCollection().insert docs
  (doc._id for doc in docs)
