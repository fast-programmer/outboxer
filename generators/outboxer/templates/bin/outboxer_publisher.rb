#!/usr/bin/env ruby

require 'bundler/setup'
require 'logger'
require 'sidekiq'

require_relative '../../../../lib/outboxer'

logger = Logger.new($stdout)
logger.level = Logger::INFO

options = Outboxer::OptionParser.parse!

Sidekiq.configure_client { |config| config.redis = { url: options[:redis_url] } }

require_relative 'workers/domain_event_handler_worker'
require_relative 'workers/log_handler_worker'

outboxer_publisher = Outboxer::Publisher.new(
  db_config: options[:db_config], poll: options[:poll], logger: logger)

trap("INT") { outboxer_publisher.stop! }

outboxer_publisher.publish! do |outboxer_message|
  case outboxer_message.outboxer_messageable_type
  when 'Models::DomainEvent'
    DomainEventHandlerWorker.perform_async({ 'id' => outboxer_message.outboxer_messageable_id })
  when 'Models::Log'
    LogHandlerWorker.perform_async({ 'id' => outboxer_message.outboxer_messageable_id })
  else
    raise "No handler defined for #{outboxer_message.outboxer_messageable_type}"
  end
end

# bin/outboxer_publisher \
#   --db_config=spec/config/database.yml
#   --poll=1
#   --redis_url=redis://localhost:6379/0
