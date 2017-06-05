$LOAD_PATH.unshift(File.dirname(__FILE__))
$stdout.sync = true

require 'raven'
require 'web'

# if ENV['SENTRY_DSN']

  #     puts "Failed to send messsage to sentry: #{event}"
  #   }
  # end

  use Raven::Rack
# end

    run WebListener
  # Raven.capture do
  #   run WebListener
  # end
