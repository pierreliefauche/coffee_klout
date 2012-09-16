request = require "request"

# Klout API wrapper.
# Only v2.
# Only JSON.
class Klout

  # Create a Klout API v2 wrapper
  #
  # key - String Klout API key. (Required)
  #
  # Returns a Klout instance
  constructor: (@key)->
    @baseUri = "http://api.klout.com/v2"

  # Make a GET request to the Klout API
  #
  # resource - String uri of the requested data, does not include hostname
  # callback - Function called on success/error
  _get: (resource, callback)->
    return unless callback

    # API key is always required
    auth = "#{if ~resource.indexOf('?') then '&' else '?'}key=#{@key}"

    request @baseUri + resource + auth, (error, response, body)->
      return callback error if error
      switch response.statusCode
        when 401 then callback new Error("Invalid authentication credentials.")
        when 403 then callback new Error("Inactive key, or call threshold reached.")
        when 404 then callback new Error("Resource or user not found.")
        when 500 then callback new Error("Klout internal server error.")
        when 502 then callback new Error("Klout is down or being upgraded.")
        when 503 then callback new Error("Klout is unavailable.")
        else
          try
            callback null, JSON.parse(body)
          catch ex
            callback ex

  # Get the Klout identity of a user (basically his Klout ID)
  # based on his ID on a different network
  #
  # options - Hash containing the different network ID. Can contain either:
  #           twitter_screen_name - String Twitter handle
  #           twitter_id          - Numeric string Twitter unique identifier, contains only numbers
  #           third_party_id      - String Facebook third party ID
  #           google_plus_id      - Numeric string Google+ user ID, usually only numbers
  #           klout_id            - Numeric string Klout user ID.
  #                                 Beware that the returned value does NOT include the Klout ID but another network user ID.
  getKloutIdentity: (options, callback)->
    if options["twitter_id"]
      path = "/tw/#{options["twitter_id"]}"

    else if options["twitter_screen_name"]
      path = "/twitter?screenName=#{options["twitter_screen_name"]}"

    else if options["google_plus_id"]
      path = "/gp/#{options["google_plus_id"]}"

    else if options["third_party_id"]
      path = "/fb/#{options["third_party_id"]}"

    else if options["klout_id"]
      path = "/klout/#{options["klout_id"]}"

    @_get "/identity.json#{path}", callback if path

  # Helper to abstract the call to getKloutIdentity to get the user’s Klout ID
  #
  # user     - String Klout ID or Hash same as `getKloutIdentity` options
  # resource - String resource path containing ':kloutId' (replaced by the user’s Klout ID)
  # callback - Function
  _getUserResource: (userId, resource, callback)->
    return unless callback

    userId = 'klout_id': user unless typeof userId is 'object'

    if userId['klout_id']
      @_get resource.replace(':kloutId', userId['klout_id']), callback
    else
      @getKloutIdentity userId, (error, identity)=>
        return callback error if error
        @_get resource.replace(':kloutId', identity.id), callback

  # Following methods reflect Klout API methods
  # http://klout.com/s/developers/v2
  #
  # the `userId` parameter is always required and similar the `_getUserResource`

  getUser: (userId, callback)->
    @_getUserResource userId, "/user.json/:kloutId", callback

  getScore: (userId, callback)->
    @_getUserResource userId, "/user.json/:kloutId/score", callback

  getTopics: (userId, callback)->
    @_getUserResource userId, "/user.json/:kloutId/topics", callback

  getInfluence: (userId, callback)->
    @_getUserResource userId, "/user.json/:kloutId/influence", callback


exports.Klout = Klout
