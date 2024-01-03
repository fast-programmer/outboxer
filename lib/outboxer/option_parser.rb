require 'optparse'

module Outboxer
  module OptionsParser
    extend self

    def parse!(options)
      options = {
        concurrency: 5,
        poll: 1,
        redis_url: 'redis://localhost:6379/0',
        handlers: {}
      }

      current_messageable_type = nil

      OptionParser.new do |opts|
        opts.banner = "Usage: outboxer_publisher.rb [options]"

        opts.on("-c", "--concurrency NUMBER", Integer, "Number of worker threads") do |concurrency|
          options[:concurrency] = concurrency.to_i
        end

        opts.on("-p", "--poll INTERVAL", Integer, "Number of seconds to wait when no results or queue full") do |interval|
          options[:poll] = interval.to_i
        end

        opts.on("-r", "--redis_url URL", "URL of the Redis server") do |url|
          options[:redis_url] = url
        end

        opts.on("-d", "--db_config PATH", "Path to config/database.yml") do |path|
          db_config_path = File.expand_path(path, Dir.pwd)
          options[:db_config] = YAML.load_file(db_config_path)[ENV.fetch('RAILS_ENV')]
        end

        opts.on("-m", "--messageable_type TYPE", "The messageable type") do |type|
          current_messageable_type = type
        end

        opts.on("-w", "--worker PATH", "Path to the worker for the current messageable type") do |worker|
          if current_messageable_type
            options[:handlers][current_messageable_type] = worker
          else
            logger.error "Please specify messageable type before the worker"

            exit
          end
        end
      end.parse!

      options
    end
  end
end
