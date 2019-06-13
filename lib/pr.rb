require 'bundler/setup'
require "graphql/client"
require "graphql/client/http"
require 'date'

require "#{File.dirname(__FILE__)}/pr/fetcher"
require "#{File.dirname(__FILE__)}/pr/formatter"

class PR; end
