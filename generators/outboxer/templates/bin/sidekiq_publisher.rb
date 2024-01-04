#!/usr/bin/env ruby

require 'bundler/setup'
require 'logger'
require 'sidekiq'
require 'optparse'
require 'pry-byebug'

require_relative '../../../../lib/outboxer'

require_relative '../workers/event_handler_worker'

binding.pry

options = {
  db_config: 'config/database.yml',
  concurrency: 5,
  poll: 1,
  redis_url: 'redis://localhost:6379/0',
  log_level: 'ERROR'
}

OptionParser.new do |opts|
  opts.banner = "Usage: outboxer_publisher.rb [options]"

  opts.on("-d", "--db_config PATH", "Path to config/database.yml") do |path|
    db_config_path = File.expand_path(path, Dir.pwd)
    options[:db_config] = YAML.load_file(db_config_path)[ENV.fetch('RAILS_ENV')]
  end

  opts.on("-c", "--concurrency NUMBER", Integer, "Number of worker threads") do |concurrency|
    options[:concurrency] = concurrency.to_i
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
end.parse!

logger = Logger.new($stdout)
logger.level = Logger.const_get(options[:log_level])

outboxer_publisher = Outboxer::Publisher.new(
  db_config: options[:db_config], poll: options[:poll], logger: logger)

trap("INT") { outboxer_publisher.stop! }

Sidekiq.configure_client { |config| config.redis = { url: options[:redis_url], size: 5 } }

outboxer_publisher.publish! do |outboxer_message|
  case outboxer_message.outboxer_messageable_type
  when 'Models::Event'
    EventHandlerWorker.perform_async({ 'id' => outboxer_message.outboxer_messageable_id })
  else
    raise "No handler defined for #{outboxer_message.outboxer_messageable_type}"
  end
end

# bin/sidekiq_publisher

# bin/sidekiq_publisher \
#   --db_config=spec/config/database.yml
#   --concurrency=5
#   --poll=1
#   --redis_url=redis://localhost:6379/0
#   --log-level=DEBUG

# generators/outboxer/templates/bin/sidekiq_publisher.rb --db_config=spec/config/database.yml

# generators/outboxer/templates/bin/sidekiq_publisher.rb \
#   --db_config=spec/config/database.yml
#   --concurrency=5
#   --poll=1
#   --redis_url=redis://localhost:6379/0
#   --log_level=DEBUG

