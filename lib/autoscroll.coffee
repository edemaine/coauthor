## Whenever route (page URL) changes, restore past scroll position after
## half a second, or top of page if we haven't been there before.
## Inspiration from https://github.com/sunstorymvp/meteor-iron-router-autoscroll

Iron.Router.plugins.autoscroll = (router, options) ->
  return unless Meteor.isClient

  lastURL = null
  pastTops = {}

  $(window).scroll ->
    lastURL = document.URL
    pastTops[lastURL] = $('body').scrollTop()

  router.onAfterAction _.debounce(->
    url = document.URL
    #console.log url, lastURL, pastTops[url] or 0
    return if url == lastURL
    lastURL = url
    $('body').animate
      scrollTop: pastTops[url] or 0
    , 200
  , 500), options
