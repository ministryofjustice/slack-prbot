class PR
  class Fetcher
    HTTP = GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
      def headers(context)
        unless token = context[:access_token] || ENV['GH_TOKEN']
          fail "Missing GitHub access token"
        end

        {
          "Authorization" => "Bearer #{token}"
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
            title
            createdAt
            author {
              login
            }
          }
        }
      }
    }
    GRAPHQL
    TeamPRQuery = GithubClient.parse <<-GRAPHQL
    query($organization: String!, $team: String!, $after: String) {
      organization(login: $organization) {
        team(slug: $team) {
          repositories(first: 100, after: $after) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              name
              pullRequests(first: 100, states: [OPEN]) {
                nodes {
                  number
                  url
                  title
                  createdAt
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
      repos = []
      more_to_fetch = true
      after = nil

      while more_to_fetch
        result = GithubClient.query(TeamPRQuery, variables: {
          organization: organization,
          team: team,
          after: after
        })

        repositories = result.data.organization.team.repositories

        repos += repositories.nodes

        page_info = repositories.page_info
        after = page_info.end_cursor
        more_to_fetch = page_info.has_next_page
      end

      repos.map { |repo|
        repo.pull_requests.nodes.map { |pr|
          {
            repo_name: repo.name,
            number: pr.number,
            title: pr.title,
            url: pr.url,
            author: pr.author.login,
            created_at: Date.parse(pr.created_at)
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
        begin
          read_team_prs(organization, team)
        rescue => e
          body(%({"text": "Couldn't read PRs for team `#{team}` in `#{organization}` organization: #{e.message}"}))
        end
      elsif text =~ /in repo ([^.]+)\.?/
        repo = Regexp.last_match[1]
        begin
          read_prs_for_repo(organization, repo)
        rescue => e
          body(%({"text": "Couldn't read PRs for repo `#{repo}` in `#{organization}` organization"}))
        end
      elsif
        usage
      end
    end

  end
end
