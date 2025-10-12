require "simplecov"
require "coveralls"

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
])

SimpleCov.start

require "spec_helper"
require "pry-byebug"
require "rack/test"
require "database_cleaner"
require "factory_bot"
require_relative "../lib/outboxer"

Dir[File.join(__dir__, "factories/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:all) do
    db_config = Outboxer::Database.config(environment: "test", pool: 2)
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
  end
end
