require "simplecov"
SimpleCov.start "rails" do
  command_name "Minitest#{ENV['TEST_ENV_NUMBER']}"
  minimum_coverage ENV.fetch("COVERAGE_MIN", 0).to_i if ENV["COVERAGE_MIN"]
end

ENV["RAILS_ENV"] ||= "test"
# Valores fixos de teste (nao sao segredos): a suite nao pode depender do .env
# local, que nao existe no GitHub Actions.
ENV["STRAVA_CLIENT_ID"] = "123456"
ENV["STRAVA_CLIENT_SECRET"] = "segredo-de-teste"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
