require "spec_helper"
require "coveralls"
require "simplecov"
require "pry-byebug"
require "rack/test"
require "database_cleaner"
require "factory_bot"
require "sidekiq"
require "sidekiq/testing"
require_relative "../lib/outboxer"

Dir[File.join(__dir__, "factories/**/*.rb")].each { |f| require f }

SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:all) do
    db_config = Outboxer::Database.config(environment: "test", concurrency: 2)
    Outboxer::Database.connect(config: db_config, logger: nil)
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    begin
      DatabaseCleaner.clean_with(:truncation)
      # Reset primary key sequences for all tables in PostgreSQL
      if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
        ActiveRecord::Base.connection.tables.each do |table|
          ActiveRecord::Base.connection.reset_pk_sequence!(table)
        end
      end
    rescue ActiveRecord::DatabaseConnectionError,
           ActiveRecord::ConnectionNotEstablished,
           ActiveRecord::StatementInvalid
      # Optionally log these errors or handle them as needed
    end

    Outboxer::Setting.create_all
  end
end
