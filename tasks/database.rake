require "bundler/setup"
require "outboxer"

require "pry-byebug"

namespace :outboxer do
  namespace :db do
    task :drop do
      environment = ENV["APP_ENV"] || ENV["RAILS_ENV"] || "development"
      db_config = Outboxer::Database.config(environment: environment, pool: 1)

      maintenance_db_config = case ENV.fetch("DATABASE_ADAPTER", "postgresql")
                              when "postgresql"
                                db_config.merge(database: "postgres")
                              when "mysql2"
                                db_config.merge(database: nil)
                              else
                                raise "Unsupported DATABASE_ADAPTER: #{adapter.inspect}"
                              end

      ActiveRecord::Base.establish_connection(maintenance_db_config)
      ActiveRecord::Base.connection.drop_database(db_config[:database])
      ActiveRecord::Base.connection.disconnect!
    end

    task :create do
      environment = ENV["APP_ENV"] || ENV["RAILS_ENV"] || "development"
      db_config = Outboxer::Database.config(environment: environment, pool: 1)

      maintenance_db_config = case ENV.fetch("DATABASE_ADAPTER", "postgresql")
                              when "postgresql"
                                db_config.merge(database: "postgres")
                              when "mysql2"
                                db_config.merge(database: nil)
                              else
                                raise "Unsupported DATABASE_ADAPTER: #{adapter.inspect}"
                              end

      ActiveRecord::Base.establish_connection(maintenance_db_config)
      ActiveRecord::Base.connection.create_database(db_config[:database])
      ActiveRecord::Base.connection.disconnect!
    end

    task :migrate do
      environment = ENV["APP_ENV"] || ENV["RAILS_ENV"] || "development"
      db_config = Outboxer::Database.config(environment: environment, pool: 1)
      ActiveRecord::Base.establish_connection(db_config)

      require_relative "../db/migrate/create_outboxer_messages"
      CreateOutboxerMessages.new.up

      require_relative "../db/migrate/create_outboxer_threads"
      CreateOutboxerThreads.new.up

      require_relative "../db/migrate/create_outboxer_exceptions"
      CreateOutboxerExceptions.new.up

      require_relative "../db/migrate/create_outboxer_frames"
      CreateOutboxerFrames.new.up

      require_relative "../db/migrate/create_outboxer_publishers"
      CreateOutboxerPublishers.new.up

      require_relative "../db/migrate/create_outboxer_signals"
      CreateOutboxerSignals.new.up

      ActiveRecord::Base.connection.disconnect!
    end

    task :seed do
      environment = ENV["APP_ENV"] || ENV["RAILS_ENV"] || "development"
      db_config = Outboxer::Database.config(environment: environment, pool: 1)
      ActiveRecord::Base.establish_connection(db_config)

      ActiveRecord::Base.connection.disconnect!
    end

    task setup: [:create, :migrate, :seed]

    task reset: [:drop, :setup]
  end
end

# RAILS_ENV=development bin/rake outboxer:db:drop
# RAILS_ENV=development bin/rake outboxer:db:create
# RAILS_ENV=development bin/rake outboxer:db:migrate
# RAILS_ENV=development bin/rake outboxer:db:seed
# RAILS_ENV=development bin/rake outboxer:db:reset
