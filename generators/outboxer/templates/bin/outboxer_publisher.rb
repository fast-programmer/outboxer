#!/usr/bin/env ruby

require 'bundler/setup'

require 'logger'
require 'optparse'
require 'sidekiq'

logger = Logger.new($stdout)
logger.level = Logger::INFO

options = { concurrency: 5, poll: 1 }

OptionParser.new do |opts|
  opts.banner = "Usage: outboxer_publisher.rb [options]"

  opts.on("-c", "--concurrency NUMBER", Integer, "Number of worker threads") do |concurrency|
    options[:concurrency] = concurrency
  end

  opts.on("-p", "--poll INTERVAL", Integer, "Number of seconds to wait when no results or queue full") do |interval|
    options[:poll] = interval
  end
end.parse!

require_relative '../workers/event_handler_worker'

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

outboxer_publisher = Outboxer::Publisher.new(
  concurrency: options[:concurrency], poll: options[:poll], logger: logger)

trap("INT") do
  logger.info "\nCTRL+C detected. Stopping outboxer publisher..."

  outboxer_publisher.stop!
end

outboxer_publisher.publish! do |outboxer_message|
  case outboxer_message.outboxer_messageable_type
  when 'Event'
    EventHandlerWorker.perform_async({ 'id' => outboxer_message.outboxer_messageable_id })
  end
end

logger.info "Exiting..."

# REDIS_URL=redis://localhost:6379/0 bin/outboxer_publisher.rb --concurrency 5 --poll 1"
