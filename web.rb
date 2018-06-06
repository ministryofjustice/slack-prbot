require 'sinatra/base'
require "graphql/client"
require "graphql/client/http"

# Main bot is in this class
class WebListener < Sinatra::Base
  HTTP = GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
    def headers(context)
      unless token = context[:access_token] || ENV['GH_TOKEN']
        fail "Missing GitHub access token"
      end

      {
        "Authorization" => "Bearer #{ENV['GH_TOKEN']}"
      }
    end
  end
  Schema = GraphQL::Client.load_schema(HTTP)
  GithubClient = GraphQL::Client.new(schema: Schema, execute: HTTP)

  RepoPRQuery = GithubClient.parse <<-GRAPHQL
    query($organization: String!, $repo: String!) {
      repository(owner: $organization, name: $repo) {
        name
        pullRequests(first: 100, states: [OPEN]) {
          nodes {
            number
            url
            id
            title
            author {
              login
            }
          }
        }
      }
    }
  GRAPHQL
  TeamPRQuery = GithubClient.parse <<-GRAPHQL
    query($organization: String!, $team: String!) {
      organization(login: $organization) {
        team(slug: $team) {
          repositories(first: 100) {
            nodes {
              name
              pullRequests(first: 100, states: [OPEN]) {
                nodes {
                  number
                  url
                  id
                  title
                  author {
                    login
                  }
                }
              }
            }
          }
        }
      }
    }
  GRAPHQL

  def read_team_prs(organization, team)
    result = GithubClient.query(TeamPRQuery, variables: {
      organization: organization,
      team: team
    })
    repos = result.data.organization.team.repositories.nodes

    repos.map { |repo|
      repo.pull_requests.nodes.map { |pr|
        {
          repo_name: repo.name,
          number: pr.number,
          title: pr.title,
          url: pr.url,
          author: pr.author.login
        }
      }
    }.flatten
  end

  def usage
    usages = [
      'open prs for team &lt;team&gt;',
      'open prs in repo &lt;repo&gt;'
    ].map { |s| "`#{s}`" }
    body %({"text": "Say one of the following: #{usages.join(', ')}"})
  end

  def pr_title(pr)
    "#{pr[:repo_name]}##{pr[:number]}: *#{pr[:title]}*"
  end

  def format_pr(pr)
    "• <#{pr[:url]}|#{pr_title(pr)}> by #{pr[:author]}"
  end

  get '/' do
    <<~EOT
      This is the webapp which is used as a Slack webhook to notify channels
      about open pull requests on select repos on github.
    EOT
  end

  def read_prs_for_repo(organization, repo)
    result = GithubClient.query(RepoPRQuery, variables: {
      organization: organization,
      repo: repo
    })

    result.data.repository.pull_requests.nodes.map { |pr|
      {
        repo_name: repo,
        number: pr.number,
        title: pr.title,
        url: pr.url,
        author: pr.author.login
      }
    }.flatten
  end

  def read_prs_for_message(organization, text)
    if text =~ /for team ([^.]+)\.?/
      team = Regexp.last_match[1]
      read_team_prs(organization, team)
    elsif text =~ /in repo ([^.]+)\.?/
      repo = Regexp.last_match[1]
      read_prs_for_repo(organization, repo)
    elsif
      usage
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

    if !ENV['WEBHOOK_TOKEN'] || params[:token] != ENV['WEBHOOK_TOKEN']
      body '{"text": "Please check the value of `WEBHOOK_TOKEN` in the environment"}'
      break
    end
    if !ENV['GH_ORG']
      body '{"text": "Please check the value of `GH_ORG` in the environment"}'
      break
    end

    begin
      prs = read_prs_for_message(ENV['GH_ORG'], params[:text])
      break unless prs.class == Array

      formatted_prs = prs.map { |pr| format_pr(pr) }
      body compose_response formatted_prs
    rescue => e
      body %({ "text": "Unhandled error: `#{e.message}`})
      raise e
    end
  end
end
