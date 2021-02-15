import {Accounts} from 'meteor/accounts-base'

unless process.env['MAIL_URL']?
  console.warn "MAIL_URL not set -- email notifications won't work!"

## Email notifications are marked as From the email address given by
## environment variable MAIL_FROM or, if that doesn't exist,
## coauthor@<host> where ROOT_URL is of the form https://<host>
Accounts.emailTemplates.from = process.env['MAIL_FROM'] ?
  "coauthor@#{require('url').parse(process.env['ROOT_URL']).hostname}"
Accounts.emailTemplates.siteName = 'Coauthor'
Accounts.emailTemplates.verifyEmail.subject = (user) ->
  "Email confirmation for Coauthor"
Accounts.emailTemplates.verifyEmail.text = (user, link) -> """
  Welcome to Coauthor, #{user.emails[0].address}!

  You (or someone claiming to be you) just registered an account with username
  "#{user.username}" on the Coauthor collaboration website,
  #{Meteor.absoluteUrl()}

  To confirm that your email address is accurate (necessary for email
  notifications to work), please click on the following link:

  #{link}
  
  If you have any questions or concerns, please reply to this email.
"""

Accounts.config
  sendVerificationEmail: true
