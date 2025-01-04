require "erb"
require "yaml"

module Outboxer
  module Database
    extend self

    def config(environment:, pool:, path: ::File.expand_path("config/database.yml", ::Dir.pwd))
      db_config_content = File.read(path)
      db_config_erb_result = ERB.new(db_config_content).result
      db_config = YAML.safe_load(db_config_erb_result, aliases: true)[environment]
      db_config["pool"] = pool
      db_config
    end

    def connect(config:, logger: nil)
      logger&.info "Outboxer connecting to database"
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection_pool.with_connection {}
      logger&.info "Outboxer connected to database"
    end

    def connected?
      ActiveRecord::Base.connected?
    end

    def disconnect(logger: nil)
      logger&.info "Outboxer disconnecting from database"
      ActiveRecord::Base.connection_handler.clear_active_connections!
      ActiveRecord::Base.connection_handler.connection_pool_list.each(&:disconnect!)
      logger&.info "Outboxer disconnected from database"
    end
  end
end
