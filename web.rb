require 'sinatra/base'
require 'github_api'

class WebListener < Sinatra::Base
  REPOS = %w( bootstrap-cfn bootstrap-salt template-deploy ).freeze
  get '/' do
    <<~EOT
      This is the webapp which is used as a Slack webhook to notify channels
      about open pull requests on select repos on github.
    EOT
  end

  post '/webhook' do
    unless ENV['WEBHOOK_TOKEN']
      status 500
      body '{ "error": { "code": 401, "message": "Please set WEBHOOK_TOKEN in the environment" } }'
      break
    end
    if params[:token] != ENV['WEBHOOK_TOKEN']
      status 401
      body '{ "error": { "code": 401, "message": "Invalid or missing token in request" } }'
      break
    end
    begin
      # TODO: check 'repos' or 'teams' in the message
      github = Github.new basic_auth: "#{ENV['GH_USER']}:#{ENV['GH_TOKEN']}", auto_pagination: true
      prs = []

      REPOS.each do |repo|
        this_repo_prs = github.pull_requests.list ENV['GH_ORG'], repo
        prs += this_repo_prs.sort_by(&:number)
      end

      messages = prs.map do |pr|
        if pr.assignee
          "• #{pr.base.repo.name}/#{pr.number}: *#{pr.title}* " \
            "by #{pr.user.login}, assigned to #{pr.assignee.login}: #{pr.html_url}"

        else
          "• #{pr.base.repo.name}/#{pr.number}: *#{pr.title}* " \
            "by #{pr.user.login}: #{pr.html_url}"
        end
      end
      if messages.any?
        response = "The following PRs are open:\n" + messages.join("\n")
        body '{ "text": "' + response.gsub('"', '\"') + '"}'
      else
        body '{ "text": "No pull requests found" }'
      end
    rescue Github::Error::Unauthorized
      status 500
      body '{ "error": { "code": 500, "message": "Could not authenticate with github." } }'
    rescue Github::Error::NotFound
      status 500
      body '{ "error": { "code": 500, "message": "Github did not understand our request. Perhaps GH_ORG is wrong?" } }'
    end
  end
end

