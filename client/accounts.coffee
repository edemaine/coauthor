Accounts.ui.config
  passwordSignupFields:
    if Meteor.settings.public.coauthor?.emailless
      'USERNAME_ONLY'
    else
      'USERNAME_AND_EMAIL'
  extraSignupFields: [
    fieldName: 'fullname'
    fieldLabel: 'Full name (FirstName LastName)'
    inputType: 'text'
  ]

Template._loginButtonsAdditionalLoggedInDropdownActions.helpers
  unverified: ->
    _.some Meteor.user().emails, (user) -> not user.verified

Template._loginButtonsAdditionalLoggedInDropdownActions.events
  'click #login-buttons-resend-verification': (e) ->
    Meteor.call 'resendVerificationEmail'
