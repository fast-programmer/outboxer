require 'erb'
require 'yaml'

module Outboxer
  module Database
    extend self

    class Error < Outboxer::Error; end

    class ConnectError < Error; end

    def config(environment:, path: 'config/database.yml')
      db_config_content = File.read(path)
      db_config_erb_result = ERB.new(db_config_content).result
      YAML.load(db_config_erb_result)[environment]
    end

    def connect!(config:, logger: nil)
      ActiveRecord::Base.logger = logger if logger

      ActiveRecord::Base.establish_connection(config)

      ActiveRecord::Base.connection_pool.with_connection {}
    rescue ActiveRecord::DatabaseConnectionError => error
      raise ConnectError.new(error.message)
    end

    def connected?
      ActiveRecord::Base.connected?
    end

    class DisconnectError < Error; end

    def disconnect!
      ActiveRecord::Base.connection_handler.clear_active_connections!
      ActiveRecord::Base.connection_handler.connection_pool_list.each(&:disconnect!)
    rescue => error
      raise DisconnectError.new(error.message)
    end
  end
end
