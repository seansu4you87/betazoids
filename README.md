# Betazoids
sad mode borky bugatchus buganuing all the binkies

# Setup
To start your Phoenix app:

  1. Install dependencies with `mix deps.get`
  2. Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  3. Start Phoenix endpoint with `mix phoenix.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).

# Design
There are three main components:
- Betazoids.Facebook
- Betazoids.Collector
- Betazoids.Endpoints

Betazoids.Facebook is a simple wrapper around the Facebook Graph API.  It's used to construct URLs and fire them off to Facebook.

Betazoids.Collector is a background process that should be constantly spawning new processes to trawl Facebook for new messages.  It persists these messages to the database.  Since messages have a detail call at `/messages/{message-id}`, the Collector will spawn additional processes to grab this information.

Betazoids.Endpoints is just a collection of typical Phoenix endpoints to serve routes and sockets.  A route is used to serve the main pages `/` and `/{betazoid-name}`.  A socket is used to provide live stats between a page and the new information the Collector grabs

## TODOs
### How to stream stats?
The Collector is constantly grabbing new information.  We can have the Collector send an event out `:new_messages` and have a listener in the channel.  The channel on receiving a `:new_messages` event, can re-query for the stats (this should be easy if we keep the stats denormalized in another table).  The channel can then push these stats to the page via the socket

### How to do stats?
Denormalized database for aggregate stats
Total Stats
- All
- All per user

Monthly over last year
- All
- All per user

Daily over last week
- All
- All per user

Hourly over last day
- All
- All per user

Redis for live stats
- active vs dead (if > 5 minutes)
- lurking (can I do this with the shitty facebook api?  I can if I can get an official 2.3 application)
- discussing vs arguing (need sentiment analysis for this)

## Learn more
  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: http://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
