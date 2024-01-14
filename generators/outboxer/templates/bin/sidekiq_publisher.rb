#!/usr/bin/env ruby

require 'bundler/setup'
require 'sidekiq'
require 'pry-byebug'

require_relative '../../../../lib/outboxer'

options = Outboxer::OptionParser.parse(ARGV)

logger = Outboxer::Logger.new($stdout, level: options[:log_level])

Outboxer::Publisher.connect!(db_config: options[:db_config], logger: logger)

trap("INT") { Outboxer::Publisher.stop! }

require_relative '../../../../spec/models/event'

Sidekiq.configure_client do |config|
  config.redis = { url: options[:redis_url], size: options[:threads_max] }
end

require_relative '../workers/event_handler_worker'

Outboxer::Publisher.publish!(
  threads_max: options[:threads_max], queue_max: options[:queue_max], poll: options[:poll]
) do |outboxer_message|
  sleep 1
  # case outboxer_message.outboxer_messageable_type
  # when 'Models::Event'
  #   EventHandlerWorker.perform_async({ 'id' => outboxer_message.outboxer_messageable_id })
  # else
  #   raise "No handler defined for #{outboxer_message.outboxer_messageable_type}"
  # end
end

# RAILS_ENV=development generators/outboxer/templates/bin/sidekiq_publisher.rb \
#   --db_config=spec/config/database.yml \
#   --queue_max=1 \
#   --threads_max=1 \
#   --poll=10 \
#   --redis_url=redis://localhost:6379/0 \
#   --log_level=DEBUG
