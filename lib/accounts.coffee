if Meteor.isServer
  Accounts.validateNewUser (user) ->
    unless user.username
      throw new Meteor.Error 403, "User must have username"
    unless validUsername user.username
      throw new Meteor.Error 403, "Invalid username; cannot contain '@' or space"
    true

Meteor.methods
  resendVerificationEmail: ->
    check Meteor.userId(), String
    unless @isSimulation
      Accounts.sendVerificationEmail Meteor.userId()
