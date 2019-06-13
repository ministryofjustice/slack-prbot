PR Bot
======

Introduction
------------

This is a simple ruby slack bot to announce open github pull requests for
selected repositories into slack.  It is based on the examples found in the
repo https://github.com/slack-ruby/slack-ruby-bot.git

Setup
-----

  * Host this app somewhere - heroku is fine.
  * You'll need to add it in slack (you will need suitable permissions for this):
    * Set up an outgoing webhook
    * Set the URL
    * Set up some suitable trigger words. `open prs, open pulls, open pull requests` is a sensible default.
    * Set some appropriate channels to listen in, or use `Any`.
  * Set up environment variables for the app as below (you can find the value for the token from your slack outgoing hook setup)
  * Optionally set up a reminder in some slack channels - something like: `/remind #<channel> every weekday at 9am open prs for team <X>`. If you want to use reminders, you'll need to add `Reminder: open prs` (or similar) to the list of trigger words.

Configuration
-------------
In the spirit of [12 factor](https://12factor.net/config), configuration is
done via the environment.  Needed settings are:

  * `WEBHOOK_TOKEN` - a token for the bot to use to authenticate to the Slack API.
  * `GH_ORG` - which github organisation to poll.
  * `GH_TOKEN` - a token for the above username. Read access to your org repos is needed.

Usage
-----

If you use the automated reminders then this will trigger a message which in turn will be sent to your bot.  But you can also perform manual queries by sending a channel message:

  * `open prs` - a default list of repositories
  * `open prs in repo <x>` - queries a specific repository
  * `open prs for team <x>` - queries all repos to which the team has access
