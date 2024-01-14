require 'bundler/setup'
Bundler.require(:default, ENV.fetch('RAILS_ENV'))

namespace :outboxer do
  namespace :db do
    task :drop do
      # brew services restart postgresql@12

      ActiveRecord::Base.establish_connection({
        'adapter' => 'postgresql', 'username' => `whoami`.strip, 'database' => 'postgres' })

      ActiveRecord::Base.connection.drop_database(db_config['database'])

      ActiveRecord::Base.connection.disconnect!
    end

    task :create do
      ActiveRecord::Base.establish_connection({
        'adapter' => 'postgresql', 'username' => `whoami`.strip, 'database' => 'postgres' })

      db_config_path = File.expand_path('config/database.yml', Dir.pwd)
      db_config = YAML.load_file(db_config_path)[ENV.fetch('RAILS_ENV')]

      ActiveRecord::Base.connection.create_database(db_config['database'])

      ActiveRecord::Base.connection.disconnect!
    end

    task :migrate do
      db_config_path = File.expand_path('config/database.yml', Dir.pwd)
      db_config = YAML.load_file(db_config_path)[ENV.fetch('RAILS_ENV')]
      ActiveRecord::Base.establish_connection(db_config)

      require_relative "../../generators/outboxer/templates/migrations/create_outboxer_messages"
      CreateOutboxerMessages.new.up

      require_relative "../../generators/outboxer/templates/migrations/create_outboxer_exceptions"
      CreateOutboxerExceptions.new.up

      # require_relative "../db/migrate/create_accounting_invoices"
      # CreateAccountingInvoices.new.up

      # require_relative "../db/migrate/create_events"
      # CreateEvents.new.up

      ActiveRecord::Base.connection.disconnect!
    end

    task :seed do
      db_config_path = File.expand_path('../config/database.yml', __dir__)
      db_config = YAML.load_file(db_config_path)[ENV.fetch('RAILS_ENV')]
      ActiveRecord::Base.establish_connection(db_config)

      require_relative "../db/seeds"

      ActiveRecord::Base.connection.disconnect!
    end

    task :setup => [:create, :migrate, :seed]

    task :reset => [:drop, :setup]
  end
end

# RAILS_ENV=development bin/rake outboxer:db:drop -f spec/tasks/database.rake
# RAILS_ENV=development bin/rake outboxer:db:create -f spec/tasks/database.rake
# RAILS_ENV=development bin/rake outboxer:db:migrate -f spec/tasks/database.rake
# RAILS_ENV=development bin/rake outboxer:db:seed -f spec/tasks/database.rake
