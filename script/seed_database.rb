#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require(:default, :development)

# psql -d postgres
# CREATE USER outboxer_developer WITH PASSWORD 'outboxer_password';
# CREATE DATABASE outboxer_development;
# GRANT ALL PRIVILEGES ON DATABASE outboxer_development TO outboxer_developer;

database_name = ENV.fetch('RAILS_ENV')
database_url = "postgres://outboxer_developer:outboxer_password@localhost/outboxer_#{database_name}"

ActiveRecord::Base.establish_connection(database_url)

# ActiveRecord::Base.establish_connection(
#   host: "localhost",
#   adapter: "postgresql",
#   database: "outboxer_development",
#   username: "outboxer_developer",
#   password: "outboxer_password")

# existing_tables = %i[outboxer_exceptions outboxer_messages]
#   .select { |table| ActiveRecord::Base.connection.table_exists?(table) }
#   .each { |existing_table| ActiveRecord::Migration.drop_table(existing_table) }

require_relative "../generators/outboxer/templates/migrations/create_outboxer_messages"
CreateOutboxerMessages.new.down
CreateOutboxerMessages.new.up


require_relative "../generators/outboxer/templates/migrations/create_outboxer_exceptions"
CreateOutboxerExceptions.new.down
CreateOutboxerExceptions.new.up

# existing_tables = %i[events accounting_invoices]
#   .select { |table| ActiveRecord::Base.connection.table_exists?(table) }
#   .each { |existing_table| ActiveRecord::Migration.drop_table(existing_table) }

require_relative "../spec/migrations/create_accounting_invoices"
CreateAccountingInvoices.new.down
CreateAccountingInvoices.new.up

require_relative "../spec/migrations/create_events"
CreateEvents.new.down
CreateEvents.new.up

require_relative "../spec/models/event"
require_relative "../spec/accounting/models/invoice"
require_relative "../spec/accounting/invoice"

require_relative "../generators/outboxer/templates/workers/event_handler_worker"

10.times do |_i|
  invoice, created_event = Accounting::Invoice.create!

  puts "Invoice##{invoice.id} - #{created_event.type} event #{event.id}"
end
