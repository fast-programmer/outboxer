require "erb"
require "yaml"

module Outboxer
  module Database
    module_function

    def config(environment: ENV["RAILS_ENV"] || "development", path: "config/database.yml")
      db_config_content = File.read(path)
      db_config_erb_result = ERB.new(db_config_content).result
      YAML.safe_load(db_config_erb_result, aliases: true)[environment]
    end

    def connect(config:, logger: Logger.new($stdout, level: Logger::INFO))
      logger&.info  "              _   _                        "
      logger&.info  "             | | | |                       "
      logger&.info  "   ___  _   _| |_| |__   _____  _____ _ __ "
      logger&.info  "  / _ \\| | | | __| '_ \\ / _ \\ \\/ / _ \\ '__|"
      logger&.info  " | (_) | |_| | |_| |_) | (_) >  <  __/ |   "
      logger&.info  "  \\___/ \\__,_|\\__|_.__/ \\___/_/\\_\\___|_|   "
      logger&.info  "                                           "
      logger&.info  "                                           "

      logger&.info "Running in ruby #{RUBY_VERSION} " \
                   "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      logger&.info "Connecting to database"
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection_pool.with_connection {}
      logger&.info "Connected to database"
    end

    def connected?
      ActiveRecord::Base.connected?
    end

    def disconnect(logger: Logger.new($stdout, level: Logger::INFO))
      logger&.info "Disconnecting from database"
      ActiveRecord::Base.connection_handler.clear_active_connections!
      ActiveRecord::Base.connection_handler.connection_pool_list.each(&:disconnect!)
      logger&.info "Disconnected from database"
    end
  end
end
