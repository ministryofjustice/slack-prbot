require 'sinatra/base'

class WebListener < Sinatra::Base
  get '/' do
    'This service has no endpoints. See https://github.com/ministryofjustice/slack-prbot for details'
  end
end

