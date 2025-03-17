require "optparse"

module Outboxer
  class OptionParser
    def self.parse(args)
      options = {}

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: outboxer_publisher [options]"

        opts.on("-c", "--concurrency INT", Integer, "Set concurrency level") do |v|
          options[:concurrency] = v
        end

        opts.on("-e", "--environment ENV", "Application environment") do |v|
          options[:environment] = v
        end

        opts.on("-b", "--buffer SIZE", Integer, "Set buffer size") do |v|
          options[:buffer] = v
        end

        opts.on("-p", "--poll NUM", Integer, "Poll interval in seconds") do |v|
          options[:poll] = v
        end

        opts.on("-C", "--config PATH", "Path to YAML config file") do |v|
          options[:config] = v
        end

        opts.on("-l", "--log-level LEVEL", "Set the logging level (debug, info, warn, error)") do |v|
          options[:log_level] = v
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
