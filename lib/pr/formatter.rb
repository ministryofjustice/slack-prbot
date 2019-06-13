class PR
  class Formatter
    def compose_response(prs)
      messages = prs.map { |pr| format_pr(pr) }
      if messages.any?
        response = "The following PRs are open:\n" + messages.join("\n")
        '{ "text": "' + response.gsub('"', '\"') + '"}'
      else
        '{ "text": "No pull requests found" }'
      end
    end

    private

    def format_pr(pr)
      pr_age = (Date.today - pr[:created_at]).to_i
      "• <#{pr[:url]}|#{pr_title(pr)}> by #{pr[:author]} (#{pr_age}d old)"
    end

    def pr_title(pr)
      "#{pr[:repo_name]}##{pr[:number]}: *#{pr[:title]}*"
    end
  end
end
