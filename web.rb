require 'sinatra/base'
require 'github_api'

class WebListener < Sinatra::Base
  DEFAULT_REPOS = %w( bootstrap-cfn bootstrap-salt template-deploy ).freeze

  get '/' do
    <<~EOT
      This is the webapp which is used as a Slack webhook to notify channels
      about open pull requests on select repos on github.
    EOT
  end

  post '/webhook' do
    content_type 'application/json'
    unless ENV['WEBHOOK_TOKEN']
      status 500
      body '{ "error": { "code": 500, "message": "Please set WEBHOOK_TOKEN in the environment" } }'
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

      if params[:text] =~ /for team (.*)/
        all_teams = github.orgs.teams.list org: 'ministryofjustice'
        team_id = all_teams.select{|t| t.name == $1 }.first.id
        repos = github.orgs.teams.list_repos team_id
        repos.each do |repo|
          this_repo_prs = github.pull_requests.list ENV['GH_ORG'], repo.name
          prs += this_repo_prs.sort_by(&:number)
        end
      elsif params[:text] =~ /in repo (.*)/
          this_repo_prs = github.pull_requests.list ENV['GH_ORG'], $1
          prs += this_repo_prs.sort_by(&:number)
      elsif params[:text] =~ /help/
        body '{"text": "Say one of the following: pulls, pulls for team &lt;team&gt;, pulls in repo &lt;repo&gt;"}'
        return
      else
        DEFAULT_REPOS.each do |repo|
          this_repo_prs = github.pull_requests.list ENV['GH_ORG'], repo
          prs += this_repo_prs.sort_by(&:number)
        end
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

