require 'bundler/setup'
require 'outboxer'

namespace :outboxer do
  namespace :db do
    task :drop do
      # brew services restart postgresql@12

      ActiveRecord::Base.establish_connection({
        'adapter' => 'postgresql', 'username' => `whoami`.strip, 'database' => 'postgres' })

      db_config_path = File.expand_path('../config/database.yml', __dir__)
      db_config = YAML.load_file(db_config_path)[ENV.fetch('OUTBOXER_ENV')]

      ActiveRecord::Base.connection.drop_database(db_config['database'])

      ActiveRecord::Base.connection.disconnect!
    end

    task :create do
      ActiveRecord::Base.establish_connection({
        'adapter' => 'postgresql', 'username' => `whoami`.strip, 'database' => 'postgres' })

      db_config_path = File.expand_path('../config/database.yml', __dir__)
      db_config = YAML.load_file(db_config_path)[ENV.fetch('OUTBOXER_ENV')]

      ActiveRecord::Base.connection.create_database(db_config['database'])

      ActiveRecord::Base.connection.disconnect!
    end

    task :migrate do
      db_config_path = File.expand_path('../config/database.yml', __dir__)
      db_config = YAML.load_file(db_config_path)[ENV.fetch('OUTBOXER_ENV')]
      ActiveRecord::Base.establish_connection(db_config)

      require_relative "../db/migrate/create_invoices"
      CreateInvoices.new.up

      require_relative "../db/migrate/create_events"
      CreateEvents.new.up

      require_relative "../db/migrate/create_outboxer_messages"
      CreateOutboxerMessages.new.up

      require_relative "../db/migrate/create_outboxer_exceptions"
      CreateOutboxerExceptions.new.up

      ActiveRecord::Base.connection.disconnect!
    end

    task :seed do
      db_config_path = File.expand_path('../config/database.yml', __dir__)
      db_config = YAML.load_file(db_config_path)[ENV.fetch('OUTBOXER_ENV')]
      ActiveRecord::Base.establish_connection(db_config)

      require_relative "../db/seeds"

      ActiveRecord::Base.connection.disconnect!
    end

    task :setup => [:create, :migrate, :seed]

    task :reset => [:drop, :setup]
  end
end

# OUTBOXER_ENV=development bin/rake outboxer:db:drop
# OUTBOXER_ENV=development bin/rake outboxer:db:create
# OUTBOXER_ENV=development bin/rake outboxer:db:migrate
# OUTBOXER_ENV=development bin/rake outboxer:db:seed
