coffee_klout
============

Wrapper for the Klout API v2.
Only V2 and JSON calls (don’t tell me you miss XML).
Accepts an optional Redis client to cache Klout API responses, especially identities.

Based on [node_klout](http://github.com/cojohn/node_klout) by Christopher John.

## The userId hash

Most Klout endpoints use the Klout ID to get information about a user.
This Klout ID is not directly related to the user’s other networks identities.

When exposing those endpoints, coffee_klout allows a hash instead of a Klout ID.
It internally makes an additional call to Klout to convert the identity.

For a Twitter handle, the userId hash would be:

```javascript
{
  "twitter_screen_name": "XXXXX"
}
```

For a Twitter ID (unique numeric ID, different from the username):

```javascript
{
  "twitter_id": "XXXXX"
}
```

For a Google+ ID:

```javascript
{
  "google_plus_id": "XXXXX"
}
```

For a Facebook Third-Party-ID:

```javascript
{
  "third_party_id": "XXXXX"
}
```

And for consistency with the Klout API:

```javascript
{
  "klout_id": "XXXXX"
}
```

# Usage

Instantiate a new instance with your Klout API key

```javascript
var Klout = require('coffee_klout');
var klout = new Klout({ key: '<YOUR_V2_KEY>' });
```

Resolve an identity (useful to retrieve the Klout user ID)

```javascript
klout.getKloutIdentity(userIdHash, function(error, identity){
  // returns a Klout identity as documented by the Klout API v2 docs
  console.log(identity.id);
});
```

The following methods are supported, where `klout_response` is an object as documented by the Klout API v2 docs
and `klout_id_or_user_id_hash` is documented above:

```javascript
klout.getUser(klout_id_or_user_id_hash, function(error, klout_response) {
	// Returns a user object
});

klout.getUserScore(klout_id_or_user_id_hash, function(error, klout_response) {
	// Returns a user's score object
});

klout.getUserTopics(klout_id_or_user_id_hash, function(error, klout_response) {
	// Returns an array of user topics
});

klout.getUserInfluence(klout_id_or_user_id_hash, function(error, klout_response) {
	// Returns a user's influence object
});
```

# Cache support

Klout suggests to store indefinitely Klout IDs obtained after requesting Klout identities.
Without such cache or storage all calls basically cost 2 API calls because one is used to convert a Twitter/Facebook/Google+ user to a Klout user.

Optional parameters can be passed to coffee_klout so it internally stores Klout identities.
It can also optionally cache other API reponses.

coffee_klout currently supports only Redis clients:

```javascript
var redis = new require('redis').createClient();

var Klout = require('coffee_klout');
var klout = new Klout({
  key: '<YOUR_V2_KEY>',
  cacheClient: redis,
  cacheLifetime: 3600 // seconds
});
```

If `cacheClient` is present, all identities will be stored to avoid resolving twice the same user ID.
If `cacheLifetime` is present (integer, seconds), other API calls are cached for the time specified.
