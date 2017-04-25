PR Bot
======

Introduction
------------

This is a simple ruby slack bot to announce open github pull requests for
selected repositories into slack.  It is based on the examples found in the
repo https://github.com/slack-ruby/slack-ruby-bot.git


Configuration
-------------
In the spirit of [12 factor](https://12factor.net/config), configuration is
done via the environment.  Needed settings are:

  * `SLACK_API_TOKEN` - a token for the bot to use to authenticate to the Slack API.
  * `GH_TOKEN` - a token for the bot to use to authenticate to github. Readaccess to your org repos is needed.
