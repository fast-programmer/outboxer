require "optparse"

module Outboxer
  class OptionParser
    DEFAULTS = {
      db_config_file: 'config/database.yml',
      config_file: 'config/outboxer.yml',
      environment: 'development',
      buffer: 100,
      tick: 0.5,
      concurrency: 1,
      verbose: false
    }

    def self.parse(args)
      parser = ::OptionParser.new do |opts|
        opts.banner = "Usage: outboxer [options]"

        opts.on("-c", "--config CONFIG", "Path to YAML config file") do |v|
          options[:config_file] = v
        end

        opts.on("--buffer SIZE", Integer, "Set buffer size") do |v|
          options[:buffer] = v
        end

        opts.on("--concurrency INT", Integer, "Set concurrency level") do |v|
          options[:concurrency] = v
        end

        opts.on("-v", "--verbose", "Print more verbose output") do
          options[:verbose] = true
        end

        opts.on("-V", "--version", "Print version and exit") do
          puts "Outboxer version #{Outboxer::VERSION}"
          exit
        end

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          exit
        end
      end

      parser.parse!(args)

      options
    end
  end
end
