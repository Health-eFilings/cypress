require 'simplecov'

SimpleCov.start 'rails'
SimpleCov.minimum_coverage 90

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

require 'minitest/spec'
require 'minitest/autorun'

require 'minitest/reporters'
Minitest::Reporters.use!
Mongo::Logger.logger.level = Logger::WARN
Mongoid.logger.level = Logger::INFO

# VVV Below worked for Mongoid 5.0.0 but not Mongoid 4.0.2 VVV
# Mongo::Logger.logger.level = Logger::INFO

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  # fixtures :all

  # Add more helper methods to be used by all tests here...
end
