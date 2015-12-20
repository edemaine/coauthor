Accounts.ui.config
  passwordSignupFields: 'USERNAME_AND_EMAIL'

Template._loginButtonsAdditionalLoggedInDropdownActions.helpers
  unverified: ->
    for email in Meteor.user().emails
      unless email.verified
        return true
    false

Template._loginButtonsAdditionalLoggedInDropdownActions.events
  'click #login-buttons-resend-verification': (e) ->
    Meteor.call 'resendVerificationEmail'
