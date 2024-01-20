require 'database_cleaner'
require 'simplecov'
require 'pry-byebug'

SimpleCov.start

require 'outboxer'

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:all) do
    Outboxer::Database.connect!(
      config_path: File.expand_path('../config/database.yml', __dir__),
      environment: 'test')

    DatabaseCleaner.strategy = :truncation
  end

  config.after(:each) do
    begin
      DatabaseCleaner.clean
     rescue ActiveRecord::DatabaseConnectionError
       # ignore
    end
  end
end
