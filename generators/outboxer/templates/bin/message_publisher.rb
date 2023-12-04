#!/usr/bin/env ruby

require_relative '../config/environment'

logger = Logger.new($stdout)
logger.level = Logger::INFO

interrupted = false

trap("INT") do
  interrupted = true

  logger.warn "\nCTRL+C detected. Preparing to exit gracefully..."
end

while !interrupted
  begin
    Outboxer::Message.publish! do |outboxer_messageable|
      case outboxer_messageable.type
      when 'Event'
        EventHandlerWorker.perform_async({ 'id' => outboxer_messageable.id })
      end
    end
  rescue => Outboxer::Message::NotFound
    sleep 1
  rescue => exception
    logger.error("Exception raised: #{exception.class}: #{exception.message}\n" \
      "#{exception.backtrace.join("\n")}")
  end
end

logger.info "Exiting..."
