Accounts.ui.config
  passwordSignupFields: 'USERNAME_AND_EMAIL'

## Prevent direct login via Dropbox (and all external services).
## This prevents creating an account without a username; also, the
## Dropbox login is not particularly nice, so not sure it really helps.
Template._loginButtonsLoggedOutAllServices.helpers
  services: [
    name: 'password'
  ]
  hasOtherServices: false

Template._loginButtonsAdditionalLoggedInDropdownActions.helpers
  unverified: ->
    for email in Meteor.user().emails
      unless email.verified
        return true
    false

Template._loginButtonsAdditionalLoggedInDropdownActions.events
  'click #login-buttons-resend-verification': (e) ->
    Meteor.call 'resendVerificationEmail'
