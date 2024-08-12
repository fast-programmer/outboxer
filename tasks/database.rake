require 'bundler/setup'
require 'outboxer'

require 'pry-byebug'

namespace :outboxer do
  namespace :db do
    task :drop do
      environment = ENV['APP_ENV'] || 'development'
      db_config = Outboxer::Database.config(environment: environment, pool: 1)

      ActiveRecord::Base.establish_connection(db_config.merge('database' => 'postgres'))
      ActiveRecord::Base.connection.drop_database(db_config['database'])
      ActiveRecord::Base.connection.disconnect!
    end

    task :create do
      environment = ENV['APP_ENV'] || 'development'
      db_config = Outboxer::Database.config(environment: environment, pool: 1)

      ActiveRecord::Base.establish_connection(db_config.merge('database' => 'postgres'))
      ActiveRecord::Base.connection.create_database(db_config['database'])
      ActiveRecord::Base.connection.disconnect!
    end

    task :migrate do
      environment = ENV['APP_ENV'] || 'development'
      db_config = Outboxer::Database.config(environment: environment, pool: 1)
      ActiveRecord::Base.establish_connection(db_config)

      require_relative "../db/migrate/create_outboxer_metrics"
      CreateOutboxerMetrics.new.up

      require_relative "../db/migrate/create_outboxer_messages"
      CreateOutboxerMessages.new.up

      require_relative "../db/migrate/create_outboxer_exceptions"
      CreateOutboxerExceptions.new.up

      require_relative "../db/migrate/create_outboxer_frames"
      CreateOutboxerFrames.new.up

      ActiveRecord::Base.connection.disconnect!
    end

    task :seed do
      environment = ENV['APP_ENV'] || 'development'
      db_config = Outboxer::Database.config(environment: environment, pool: 1)
      ActiveRecord::Base.establish_connection(db_config)

      require_relative "../db/seeds"

      ActiveRecord::Base.connection.disconnect!
    end

    task :setup => [:create, :migrate, :seed]

    task :reset => [:drop, :setup]
  end
end

# APP_ENV=development bin/rake outboxer:db:drop
# APP_ENV=development bin/rake outboxer:db:create
# APP_ENV=development bin/rake outboxer:db:migrate
# APP_ENV=development bin/rake outboxer:db:seed
# APP_ENV=development bin/rake outboxer:db:reset
