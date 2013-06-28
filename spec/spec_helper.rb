require 'celluloid/dashboard'
require 'rspec'
require 'rack/test'
require 'pry'

RSpec.configure do |config|
  config.color_enabled = true
  config.include Rack::Test::Methods
end

Celluloid.logger = nil
