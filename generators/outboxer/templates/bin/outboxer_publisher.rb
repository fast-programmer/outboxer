#!/usr/bin/env ruby

require 'bundler/setup'
require 'logger'
require 'sidekiq'
require 'pry-byebug'

require_relative '../../../../lib/outboxer'

logger = Logger.new($stdout)
logger.level = Logger::INFO

options = Outboxer::OptionParser.parse!

Sidekiq.configure_client { |config| config.redis = { url: options[:redis_url] } }
options[:handlers].values.each { |worker_path| require_relative worker_path }

outboxer_publisher = Outboxer::Publisher.new(
  db_config: options[:db_config], poll: options[:poll], logger: logger)

trap("INT") { outboxer_publisher.stop! }

outboxer_publisher.publish! do |outboxer_message|
  handler = options[:handlers][outboxer_message.outboxer_messageable_type]
  handler.constantize.perform_async({ 'id' => outboxer_message.outboxer_messageable_id })
end

# bin/outboxer_publisher \
#   --db_config=spec/config/database.yml
#   --poll=1
#   --redis_url=redis://localhost:6379/0
#   --messageable_type=Models::DomainEvent --worker=workers/domain_event_handler_worker.rb \
#   --messageable_type=Models::Log         --worker=workers/log_handler_worker.rb
