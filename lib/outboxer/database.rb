require "erb"
require "yaml"

module Outboxer
  module Database
    module_function

    CONFIG_DEFAULTS = {
      environment: "development",
      concurrency: 1,
      path: "config/database.yml"
    }

    def config(environment: CONFIG_DEFAULTS[:environment],
               concurrency: CONFIG_DEFAULTS[:pool],
               path: CONFIG_DEFAULTS[:path])
      path_expanded = ::File.expand_path(path)
      text = File.read(path_expanded)
      erb = ERB.new(text, trim_mode: "-")
      erb.filename = path_expanded
      erb_result = erb.result
      yaml = YAML.safe_load(erb_result, permitted_classes: [Symbol], aliases: true)
      yaml.deep_symbolize_keys!
      yaml = yaml[environment.to_sym] || {}
      yaml[:pool] = concurrency + 2 # concurency + main + heartbeat

      yaml
    rescue Errno::ENOENT
      {}
    end

    def connect(config:, logger: nil)
      ActiveRecord::Base.logger = logger

      logger&.info "Outboxer connecting to database"
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SELECT 1")
      end
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
