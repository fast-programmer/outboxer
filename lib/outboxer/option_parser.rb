require 'optparse'

module Outboxer
  module OptionParser
    extend self

    DEFAULT_OPTIONS = {
      db_config: 'config/database.yml',
      threads_max: 5,
      queue_max: 5,
      poll: 1,
      redis_url: 'redis://localhost:6379/0',
      log_level: 'ERROR'
    }

    def parse(args)
      options = DEFAULT_OPTIONS.dup

      ::OptionParser.new do |opts|
        opts.banner = "Usage: outboxer_publisher.rb [options]"

        opts.on("-d", "--db_config PATH", "Path to config/database.yml") do |path|
          db_config_path = File.expand_path(path, Dir.pwd)
          options[:db_config] = YAML.load_file(db_config_path)[ENV.fetch('RAILS_ENV')]
        end

        opts.on("-t", "--threads_max NUMBER", Integer, "Number of worker threads") do |threads_max|
          options[:threads_max] = threads_max.to_i
        end

        opts.on("-q", "--queue_max NUMBER", Integer, "Maximum number of items in the queue") do |queue_max|
          options[:queue_max] = queue_max
        end

        opts.on("-p", "--poll INTERVAL", Integer, "Number of seconds to wait when no results or queue full") do |interval|
          options[:poll] = interval.to_i
        end

        opts.on("-r", "--redis_url URL", "URL of the Redis server") do |url|
          options[:redis_url] = url
        end

        opts.on("-l", "--log_level LEVEL", "Set the log level (DEBUG, INFO, WARN, ERROR, FATAL)") do |log_level|
          options[:log_level] = log_level
        end
      end.parse!(args)

      options
    end
  end
end

