#!/usr/bin/env ruby

require 'bundler/setup'
require 'logger'
require 'optparse'
require 'sidekiq'
require 'pry-byebug'

require_relative '../../../../lib/outboxer'

logger = Logger.new($stdout)
logger.level = Logger::INFO

options = {
  concurrency: 5,
  poll: 1,
  redis_url: 'redis://localhost:6379/0',
  db_config: 'config/database.yml'
}

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
    options[:db_config] = path
  end
end.parse!

db_config_path = File.expand_path(options[:db_config], Dir.pwd)
db_config = YAML.load_file(db_config_path)[ENV.fetch('RAILS_ENV')]

ActiveRecord::Base.establish_connection(db_config.merge({ 'pool' => options[:concurrency] + 1 }))

Sidekiq.configure_client do |config|
  config.redis = { url: options[:redis_uri] }
end

require_relative '../workers/event_handler_worker'

outboxer_publisher = Outboxer::Publisher.new(
  concurrency: options[:concurrency], poll: options[:poll], logger: logger)

trap("INT") do
  outboxer_publisher.stop!
end

outboxer_publisher.publish! do |outboxer_message|
  binding.pry
  case outboxer_message.outboxer_messageable_type
  when 'Event'
    EventHandlerWorker.perform_async({ 'id' => outboxer_message.outboxer_messageable_id })
  end
end

logger.info "Exiting..."

# gem
# RAILS_ENV=development bin/rake outboxer:db:reset -f spec/tasks/database.rake
# RAILS_ENV=development generators/outboxer/templates/bin/outboxer_publisher.rb --db_config=spec/config/database.yml

# app
# RAILS_ENV=development bin/outboxer_publisher # --db_config=config/database.yml

# RAILS_ENV=development bin/outboxer_publisher --type=Event --worker=workers/event_handler_worker.rb

# RAILS_ENV=development bin/outboxer_publisher --type=Models::DomainEvent --worker=workers/domain_event_handler_worker.rb
