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
