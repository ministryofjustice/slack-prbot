require 'sinatra/base'
require 'github_api'

# Main bot is in this class
class WebListener < Sinatra::Base
  attr_accessor :github

  DEFAULT_REPOS = %w[bootstrap-cfn bootstrap-salt template-deploy].freeze

  def get_team_id(name)
    all_teams = @github.orgs.teams.list org: 'ministryofjustice'
    all_teams.select { |t| t.name == name }.first.id
  end

  def read_team_prs(team)
    team_id = get_team_id team
    repos = @github.orgs.teams.list_repos team_id
    repos.map { |repo| read_prs_for_repo repo.name }.flatten
  end

  def read_default_repos
    DEFAULT_REPOS.map do |repo|
      read_prs_for_repo repo
    end.flatten
  end

  def usage
    usages = [
      'open prs',
      'open prs for team &lt;team&gt;',
      'open prs in repo &lt;repo&gt;'
    ]
    body %({"text": "Say one of the following: #{usages.join(',')}"})
  end

  def pr_title(pr)
    "#{pr.base.repo.name}/#{pr.number}: #{pr.title}"
  end

  def format_pr(pr)
    if pr.assignee
      "• #{pr_title(pr)} by #{pr.user.login}, assigned to #{pr.assignee.login}: #{pr.html_url}"

    else
      "• #{pr_title(pr)} by #{pr.user.login}: #{pr.html_url}"
    end
  end

  get '/' do
    <<~EOT
      This is the webapp which is used as a Slack webhook to notify channels
      about open pull requests on select repos on github.
    EOT
  end

  def read_prs_for_repo(repo)
    this_repo_prs = @github.pull_requests.list ENV['GH_ORG'], repo
    this_repo_prs.sort_by(&:number)
  end

  def read_prs_for_message(text)
    if text =~ /for team (.*)/
      read_team_prs Regexp.last_match[1]
    elsif text =~ /in repo (.*)/
      read_prs_for_repo Regexp.last_match[1]
    elsif text =~ /help/
      usage
    else
      read_default_repos
    end
  end

  def compose_response(messages)
    if messages.any?
      response = "The following PRs are open:\n" + messages.join("\n")
      '{ "text": "' + response.gsub('"', '\"') + '"}'
    else
      '{ "text": "No pull requests found" }'
    end
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
      @github = Github.new basic_auth: "#{ENV['GH_USER']}:#{ENV['GH_TOKEN']}", auto_pagination: true

      prs = read_prs_for_message(params[:text])
      break unless prs

      formatted_prs = prs.map { |pr| format_pr(pr) }
      body compose_response formatted_prs
    rescue Github::Error::Unauthorized
      status 500
      body '{ "error": { "code": 500, "message": "Could not authenticate with github." } }'
    rescue Github::Error::NotFound
      status 500
      message = 'Github did not understand our request. Perhaps GH_ORG is wrong?'
      body %({ "error": { "code": 500, "message": #{message} } })
    end
  end
end
