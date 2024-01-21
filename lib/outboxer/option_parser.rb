require 'optparse'
require 'pry-byebug'

module Outboxer
  class OptionParser
    def self.parse!(default_options = {})
      options = default_options.dup

      options.merge!({
        environment: 'development',
        db_config_path: 'config/database.yml',
        threads_max: 5,
        queue_max: 5,
        poll: 1,
        log_level: 'ERROR' })

      option_parser = ::OptionParser.new do |opts|
        opts.on("-e", "--environment ENVIRONMENT", "Set the environment") do |environment|
          options[:environment] = environment
        end

        opts.on("-d", "--db_config_path PATH", "Path to config/database.yml") do |db_config_path|
          options[:db_config_path] = db_config_path
        end

        opts.on("-t", "--threads_max NUMBER", Integer, "Number of worker threads") do |threads_max|
          options[:threads_max] = threads_max
        end

        opts.on("-q", "--queue_max NUMBER", Integer, "Maximum number of items in the queue") do |queue_max|
          options[:queue_max] = queue_max
        end

        opts.on("-p", "--poll INTERVAL", Integer, "Number of seconds to wait when no results or queue full") do |interval|
          options[:poll] = interval
        end

        opts.on("-l", "--log_level LEVEL", "Set the log level (DEBUG, INFO, WARN, ERROR, FATAL)") do |log_level|
          options[:log_level] = log_level
        end

        yield opts if block_given?
      end

      option_parser.parse!

      options
    end
  end
end
