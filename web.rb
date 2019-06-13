require 'sinatra/base'
require './lib/pr'

class WebListener < Sinatra::Base

  get '/' do
    <<~EOT
      This is the webapp which is used as a Slack webhook to notify channels
      about open pull requests on select repos on github.
    EOT
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
      fetcher = PR::Fetcher.new
      formatter = PR::Formatter.new

      prs = fetcher.read_prs_for_message(ENV['GH_ORG'], params[:text])
      break unless prs.class == Array

      body formatter.compose_response(prs)
    rescue => e
      body %({ "text": "Unhandled error: `#{e.message}`})
      raise e
    end
  end
end
