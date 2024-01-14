#!/usr/bin/env ruby

require 'bundler/setup'
require 'sidekiq'
require 'optparse'

require 'pry-byebug'

require_relative '../../../../lib/outboxer'

DEFAULT_OPTIONS = {
  db_config: 'config/database.yml',
  threads_max: 5,
  queue_max: 5,
  poll: 1,
  redis_url: 'redis://localhost:6379/0',
  log_level: 'ERROR'
}

options = DEFAULT_OPTIONS.dup

OptionParser.new do |opts|
  opts.banner = "Usage: sidekiq_publisher.rb [options]"

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
end.parse!(ARGV)

logger = Outboxer::Logger.new($stdout, level: options[:log_level])

Outboxer::Publisher.connect!(db_config: options[:db_config])

trap("INT") { Outboxer::Publisher.stop! }

require_relative '../../../../spec/models/event'

Sidekiq.configure_client do |config|
  config.redis = { url: options[:redis_url], size: options[:threads_max] }
  # config.logger = logger
end

require_relative '../workers/event_handler_worker'

Outboxer::Publisher.publish!(
  threads_max: options[:threads_max],
  queue_max: options[:queue_max],
  poll: options[:poll],
  logger: logger
) do |outboxer_message|
  case outboxer_message.outboxer_messageable_type
  when 'Models::Event'
    EventHandlerWorker.perform_async({ 'id' => outboxer_message.outboxer_messageable_id })
  else
    raise "No handler defined for #{outboxer_message.outboxer_messageable_type}"
  end
end

# RAILS_ENV=development generators/outboxer/templates/bin/sidekiq_publisher.rb \
#   --db_config=spec/config/database.yml \
#   --queue_max=1 \
#   --threads_max=1 \
#   --poll=10 \
#   --redis_url=redis://localhost:6379/0 \
#   --log_level=DEBUG
