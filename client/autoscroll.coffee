## Whenever route (page URL) changes, restore past scroll position after
## half a second, or top of page if we haven't been there before.
## Inspiration from https://github.com/iron-meteor/iron-router/issues/96 and
## https://github.com/sunstorymvp/meteor-iron-router-autoscroll

lastURL = null
pastTops = {}

$(window).scroll ->
  lastURL = document.URL
  pastTops[lastURL] = $('body').scrollTop()

## Find all templates that correspond to routes
for route in Router.routes
  template = route.options.template ? route.options.name
  Template[template].onRendered ->
    url = document.URL
    #console.log url, lastURL, pastTops[url] or 0
    return if url == lastURL
    lastURL = url
    $('body').animate
      scrollTop: pastTops[url] or 0
    , 200
