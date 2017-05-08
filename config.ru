$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'prbot'
require 'web'

Thread.abort_on_exception = true

Thread.new do
  begin
    PRBot.run
  rescue Exception => e
    STDERR.puts "ERROR: #{e}"
    STDERR.puts e.backtrace
    raise e
  end
end

run WebListener
