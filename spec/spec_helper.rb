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
    db_config = {
      'adapter' => 'postgresql',
      'username' => `whoami`.strip,
      'database' => 'outboxer_test'
    }

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

  # config.after(:all) do
  #   Publisher.disconnect!
  # end

  # config.before(:each) do
  #   ActiveRecord::Base.establish_connection({
  #     'adapter' => 'postgresql',
  #     'username' => `whoami`.strip,
  #     'database' => 'outboxer_test'
  #   })

  #   DatabaseCleaner.strategy = :truncation
  # end

  # config.after(:each) do
  #   DatabaseCleaner.clean
  # end
end
