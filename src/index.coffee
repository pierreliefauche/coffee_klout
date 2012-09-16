request = require "request"

# Klout API wrapper.
# Only v2.
# Only JSON.
# Only Redis.
class Klout
  baseUri: "http://api.klout.com/v2"

  # Create a Klout API v2 wrapper
  #
  # options - Hash
  #           key           - String Klout API key. (Required)
  #           cacheClient   - Object Configured Redis client, ready to use (Optional)
  #           cacheLifetime - Integer TTL for storing API responses (other than identities) in cache (Optional)
  #
  # If a Redis client is provided, all calls to resolve
  # identities will be cached (TTL set to several years)
  # If a cache lifetime is provided, other API calls will
  # also be cached for the time specified (will not affect
  # identities cache TTL)
  #
  # Returns a Klout instance
  constructor: (options)->
    @key = options.key
    @cache = options.cacheClient
    @cacheLifetime = options.cacheLifetime

  # Fetch an object from cache, if a cache is configured
  _getFromCache: (key, callback)->
    return callback "No cache set" unless @cache
    @cache.get key, (error, result)->
      return callback error or 'No cached value' if error or not result
      callback null, JSON.parse(result)

  # Set an object in cache, if a cache is configured
  _setInCache: (key, value, ttl, callback)->
    return callback "No cache set" unless @cache
    @cache.set key, JSON.stringify(value), (error)=>
      callback error
      @cache.expire key, ttl if ttl and not error

  # Make a GET request to the Klout API
  #
  # resource - String uri of the requested data, does not include hostname
  # cacheTTL - Integer lifetime of the response in cache (response won’t be cached if absent)
  # callback - Function called on success/error
  _get: (resource, cacheTTL, callback)->
    return unless callback

    # Check cache
    @_getFromCache resource, (error, result)=>
      return callback null, result unless error

      # Cache empty or not configured, so execute the request

      # API key is always required
      auth = "#{if ~resource.indexOf('?') then '&' else '?'}key=#{@key}"
      console.log 'will request', resource
      request @baseUri + resource + auth, (error, response, body)=>
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
              data = JSON.parse(body)
              callback null, data
              @_setInCache resource, data, cacheTTL, (->) if cacheTTL
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

    # 10 Years = an eternity of cache, as Klout suggests
    @_get "/identity.json#{path}", 315576000, callback if path

  # Helper to abstract the call to getKloutIdentity to get the user’s Klout ID
  #
  # user     - String Klout ID or Hash same as `getKloutIdentity` options
  # resource - String resource path containing ':kloutId' (replaced by the user’s Klout ID)
  # callback - Function
  _getUserResource: (userId, resource, callback)->
    return unless callback

    userId = 'klout_id': userId unless typeof userId is 'object'

    if userId['klout_id']
      @_get resource.replace(':kloutId', userId['klout_id']), @cacheLifetime, callback
    else
      @getKloutIdentity userId, (error, identity)=>
        return callback error if error
        @_get resource.replace(':kloutId', identity.id), @cacheLifetime, callback

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
