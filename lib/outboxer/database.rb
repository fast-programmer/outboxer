require 'erb'
require 'yaml'

module Outboxer
  module Database
    extend self

    class Error < Outboxer::Error; end

    class ConnectError < Error; end

    def connect!(config_path:, environment:, logger: nil)
      ActiveRecord::Base.logger = logger if logger

      config_erb_result = ERB.new(File.read(config_path)).result
      yaml_config = YAML.load(config_erb_result)

      configurations = ActiveRecord::DatabaseConfigurations.new(yaml_config)
      config_hash = configurations.configs_for(env_name: environment)[0].configuration_hash

      ActiveRecord::Base.establish_connection(config_hash)

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
