require 'simplecov'
SimpleCov.start
require 'database_cleaner'
require 'pry-byebug'
require 'factory_bot'

Dir[File.join(__dir__, 'factories/**/*.rb')].each { |f| require f }

require_relative '../lib/outboxer'

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include FactoryBot::Syntax::Methods

  config.before(:all) do
    db_config = Outboxer::Database.config(environment: 'test', pool: 2)
    Outboxer::Database.connect(config: db_config, logger: nil)

    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    begin
      DatabaseCleaner.clean_with(:truncation)

      ActiveRecord::Base.connection.tables.each do |table|
        if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
          ActiveRecord::Base.connection.reset_pk_sequence!(table)
        end
      end
    rescue ActiveRecord::DatabaseConnectionError,
        ActiveRecord::ConnectionNotEstablished,
        ActiveRecord::StatementInvalid
      # ignore
    end

    Outboxer::Settings.create
  end
end
