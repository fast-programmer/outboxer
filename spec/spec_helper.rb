require "outboxer"
require 'pry-byebug'

require_relative "../generators/outboxer/templates/migrations/create_outboxer_messages"
require_relative "../generators/outboxer/templates/migrations/create_outboxer_exceptions"


RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    # psql -d postgres
    # CREATE USER outboxer_tester WITH PASSWORD 'outboxer_tester';
    # CREATE DATABASE outboxer_test;
    # GRANT ALL PRIVILEGES ON DATABASE outboxer_test TO outboxer_tester;

    ActiveRecord::Base.establish_connection(
      host: "localhost",
      adapter: "postgresql",
      database: "outboxer_test",
      username: "outboxer_tester",
      password: "outboxer_password")

    require_relative "models/event"
    require_relative "accounting/models/invoice"
    require_relative "accounting/invoice"
    require_relative "event_handler_worker"
  end

  config.before(:each) do
    existing_tables = %i[outboxer_exceptions outboxer_messages]
      .select { |table| ActiveRecord::Base.connection.table_exists?(table) }

    existing_tables.each do |existing_table|
      ActiveRecord::Migration.drop_table(existing_table)
    end

    existing_tables = %i[events accounting_invoices]
      .select { |table| ActiveRecord::Base.connection.table_exists?(table) }

    existing_tables.each do |existing_table|
      ActiveRecord::Migration.drop_table(existing_table)
    end

    CreateOutboxerMessages.new.change
    CreateOutboxerExceptions.new.change

    ActiveRecord::Schema.define do
      create_table :accounting_invoices, force: true do |t|
        t.integer :lock_version, default: 0, null: false

        t.timestamps null: false
      end

      create_table :events, force: true do |t|
        t.text :type, null: false
        t.jsonb :payload

        t.datetime :created_at, null: false

        t.references :eventable, polymorphic: true, null: false, index: true
      end

      add_index :events, [:eventable_type, :eventable_id, :created_at],
        name: 'index_events_on_eventable_and_created_at'
    end
  end
end
