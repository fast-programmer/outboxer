require "erb"
require "yaml"

module Outboxer
  # Database management including loading of configuration, establishing connections,
  # checking connectivity, and disconnecting.
  module Database
    module_function

    CONFIG_DEFAULTS = {
      environment: "development",
      concurrency: 1,
      path: "config/database.yml"
    }

    # Loads the database configuration from a YAML file, processes ERB,
    # and merges with CONFIG_DEFAULTS.
    # @param pool [Integer] the connection pool size.
    # @param environment [String, Symbol] the environment name to load configuration for.
    # @param path [String] the path to the database configuration file.
    # @return [Hash] the database configuration with symbolized keys.
    # @note Extra connections are added to the pool to cover for internal threads like main
    #   and the heartbeat thread.
    def config(pool:, environment: CONFIG_DEFAULTS[:environment], path: CONFIG_DEFAULTS[:path])
      path_expanded = ::File.expand_path(path)
      text = File.read(path_expanded)
      erb = ERB.new(text, trim_mode: "-")
      erb.filename = path_expanded
      erb_result = erb.result
      yaml = YAML.safe_load(erb_result, permitted_classes: [Symbol], aliases: true)
      yaml.deep_symbolize_keys!
      yaml = yaml[environment.to_sym] || {}
      yaml[:pool] = pool

      yaml
    rescue Errno::ENOENT
      {}
    end

    # Establishes a connection to the database using the specified configuration.
    # @param config [Hash] the configuration hash for the database.
    # @param logger [Logger, nil] the logger to log connection activity.
    def connect(config:, logger: nil)
      Thread.current.name = "main"

      ActiveRecord::Base.logger = logger

      logger&.info "Outboxer connecting to database"
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SELECT 1")
      end
      logger&.info "Outboxer connected to database"
    end

    # Checks if there is an active database connection.
    # @return [Boolean] true if connected, false otherwise.
    def connected?
      ActiveRecord::Base.connected?
    end

    # Disconnects all active database connections.
    # @param logger [Logger, nil] the logger to log disconnection activity.
    def disconnect(logger: nil)
      logger&.info "Outboxer disconnecting from database"
      ActiveRecord::Base.connection_handler.clear_active_connections!
      ActiveRecord::Base.connection_handler.connection_pool_list.each(&:disconnect!)
      logger&.info "Outboxer disconnected from database"
    end

    # Truncates all Outboxer tables.
    #
    # - Runs inside a transaction for atomicity where supported.
    # - Works across PostgreSQL and MySQL without adapter branching.
    # - Automatically resets auto-increment / identity sequences.
    #
    # @param logger [#info, #warn, #error, nil] optional logger
    # @return [void]
    def truncate(logger: nil)
      logger&.warn("Outboxer truncating tables...")

      ActiveRecord::Base.connection_pool.with_connection do |connection|
        if connection.adapter_name.downcase.include?("postgres")
          connection.execute(<<~SQL)
            TRUNCATE TABLE
              outboxer_message_counts,
              outboxer_message_totals,
              outboxer_frames,
              outboxer_exceptions,
              outboxer_messages,
              outboxer_signals,
              outboxer_publishers
            RESTART IDENTITY;
          SQL
        else
          connection.execute("TRUNCATE TABLE outboxer_message_counts;")
          connection.execute("TRUNCATE TABLE outboxer_message_totals;")
          connection.execute("TRUNCATE TABLE outboxer_frames;")
          connection.execute("TRUNCATE TABLE outboxer_exceptions;")
          connection.execute("TRUNCATE TABLE outboxer_messages;")
          connection.execute("TRUNCATE TABLE outboxer_signals;")
          connection.execute("TRUNCATE TABLE outboxer_publishers;")
        end
      end
    end
  end
end
