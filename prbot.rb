#!/usr/bin/env ruby
require 'slack-ruby-bot'

SlackRubyBot::Client.logger.level = Logger::WARN

# PullRequest bot to announce open PRs to slack
class PRBot < SlackRubyBot::Bot
  REPOS = %w( bootstrap-cfn bootstrap-salt template-deploy ).freeze

  help do
    title 'PullRequest Bot'
    desc 'This bot will give a daily report of open PRs on watched repos.'

    command 'repos' do
      desc 'Tells you which repos are watched'
      long_desc 'This will give a list of which repositories are polled for open pull requests.' \
                ' Currently this is a static list, though this is subject to change in future'   \
                ' versions.'
    end

    command 'open' do
      desc 'Lists the open PRs for the watched repos'
      long_desc "Queries github, finding open pull-requests on all repos that are watched.\n" \
                'Use this to trigger a manual report.'
    end
  end

  command 'repos' do |client, data, _match|
    message = "I am watching the following repos: #{REPOS.join ', '}"
    client.say(channel: data.channel, text: message)
  end

  command 'open' do |client, data, _match|
    client.say(channel: data.channel, text: 'Command not implemented yet')
  end
end

PRBot.run
