#!/usr/bin/env ruby

require_relative '../config/environment'

logger = Logger.new($stdout)
logger.level = Logger::INFO

loop do
  Outboxer::Event.publish! do |outboxer_eventable|
    EventHandlerWorker.perform_async({ 'event' => { 'id' => outboxer_eventable.id } })
  end
rescue Interrupt
  logger.warn "\nCTRL+C detected. Exiting gracefully..."

  break
rescue => Outboxer::Event::NotFound
  sleep 1
rescue => exception
  logger.error("Exception raised: #{exception.class}: #{exception.message}\n" \
    "#{exception.backtrace.join("\n")}")

  sleep 1
end
