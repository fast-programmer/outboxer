require 'bundler/setup'
Bundler.require(:default, ENV.fetch('RAILS_ENV'))

# require 'active_record'
# require 'yaml'

namespace :outboxer do
  namespace :db do
    task :drop do
      # brew services restart postgresql@12

      db_config_path = File.expand_path('../config/database.yml', __dir__)
      db_config = YAML.load_file(db_config_path)[ENV.fetch('RAILS_ENV')]
      ActiveRecord::Base.establish_connection(db_config)

      ActiveRecord::Base.connection.drop_database(db_config['database'])
    end

    task :create do
      db_config_path = File.expand_path('../config/database.yml', __dir__)
      db_config = YAML.load_file(db_config_path)[ENV.fetch('RAILS_ENV')]
      ActiveRecord::Base.establish_connection(db_config.merge('database' => 'postgres'))

      # ActiveRecord::Base.connection.execute("ALTER USER #{db_config['username']} CREATEDB;")
      ActiveRecord::Base.connection.create_database(db_config['database'])
    end

    task :migrate do
      db_config_path = File.expand_path('../config/database.yml', __dir__)
      db_config = YAML.load_file(db_config_path)[ENV.fetch('RAILS_ENV')]
      ActiveRecord::Base.establish_connection(db_config)

      require_relative "../generators/outboxer/templates/migrations/create_outboxer_messages"
      # CreateOutboxerMessages.new.down
      CreateOutboxerMessages.new.up

      require_relative "../generators/outboxer/templates/migrations/create_outboxer_exceptions"
      # CreateOutboxerExceptions.new.down
      CreateOutboxerExceptions.new.up

      require_relative "../spec/migrations/create_accounting_invoices"
      # CreateAccountingInvoices.new.down
      CreateAccountingInvoices.new.up

      require_relative "../spec/migrations/create_events"
      # CreateEvents.new.down
      CreateEvents.new.up
    end
  end
end

# RAILS_ENV=development bin/rake outboxer:db:connect -f spec/tasks/database.rake
# RAILS_ENV=test bin/rake outboxer:db:connect -f spec/tasks/database.rake
