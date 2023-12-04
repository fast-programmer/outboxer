#!/usr/bin/env ruby

require_relative '../config/environment'

logger = Logger.new($stdout)
logger.level = Logger::INFO

running = true

trap("INT") do
  running = false

  logger.warn "\nCTRL+C detected. Preparing to exit gracefully..."
end

while running
  begin
    Outboxer::Message.publish! do |outboxer_messageable|
      case outboxer_messageable.class.name
      when 'Models::Event'
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
