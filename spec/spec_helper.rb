require 'database_cleaner'
require 'simplecov'
require 'pry-byebug'

SimpleCov.start

require 'outboxer'

env = ENV['RAILS_ENV'] || 'development'

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:all) do
    # db_config = {
    #   'adapter' => 'postgresql',
    #   'username' => `whoami`.strip,
    #   'database' => 'outboxer_test'
    # }

    # db_config = {
    #   'adapter' => 'postgresql',
    #   'username' => 'outboxer_tester',
    #   'password' => 'outboxer_password',
    #   'database' => 'outboxer_test',
    #   'host' => 'localhost',
    #   'port' => 5432
    # }

    db_config_path = File.expand_path('config/database.yml', Dir.pwd)
    db_config = YAML.load_file(db_config_path)[env]

    Outboxer::Publisher.connect!(db_config: db_config)

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
