Meteor.methods
  resendVerificationEmail: ->
    check Meteor.userId(), String
    unless @isSimulation
      Accounts.sendVerificationEmail Meteor.userId()
