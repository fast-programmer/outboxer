#!/usr/bin/env ruby

require 'bundler/setup'

require 'logger'
require 'optparse'
require 'sidekiq'
# require 'outboxer'
require_relative '../../../../lib/outboxer'

logger = Logger.new($stdout)
logger.level = Logger::INFO

options = { concurrency: 5, poll: 1 }

OptionParser.new do |opts|
  opts.banner = "Usage: outboxer_publisher.rb [options]"

  opts.on("-c", "--concurrency NUMBER", Integer, "Number of worker threads") do |concurrency|
    options[:concurrency] = concurrency.to_i
  end

  opts.on("-p", "--poll INTERVAL", Integer, "Number of seconds to wait when no results or queue full") do |interval|
    options[:poll] = interval.to_i
  end
end.parse!

require_relative '../workers/event_handler_worker'

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

ActiveRecord::Base.establish_connection(
  host: "localhost",
  adapter: "postgresql",
  database: "outboxer_development",
  username: "outboxer_developer",
  password: "outboxer_password",
  pool: options[:concurrency] + 1)

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

# REDIS_URL=redis://localhost:6379/0 generators/outboxer/templates/bin/outboxer_publisher.rb --concurrency 5 --poll 1"
