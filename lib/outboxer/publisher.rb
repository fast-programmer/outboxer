require 'thread'
require 'logger'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: publisher.rb [options]"

  opts.on("-p", "--poll-interval INTERVAL", Integer, "Polling interval in seconds") do |interval|
    options[:poll_interval] = interval
  end
end.parse!

POLL_INTERVAL = options[:poll_interval] || 1

logger = Logger.new(STDOUT)

running = true

def publish_message!(outboxer_messageable)
  # case outboxer_messageable.class.name
  # when 'Event'
  #   EventHandlerWorker.perform_async({ 'id' => outboxer_messageable.id })
  # end
end

Signal.trap('INT') do
  running = false
end

while running
  begin
    messages = Outboxer::Message.unpublished!(limit: 1)

    if !messages.empty?
      messages.each do |message|
        begin
          publish_message! outboxer_message.outboxer_messageable
        rescue => exception
          Outboxer::Message.failed!(id: outboxer_message.id, exception: exception)

          raise
        end

        Outboxer::Message.published!(id: outboxer_message.id)
      end
    else
      sleep POLL_INTERVAL
    end
  rescue => exception
    logger.error "Error: #{exception.class}: #{exception.message}"
  end
end

while !queue.empty?
  sleep POLL_INTERVAL
end

threads.each(&:join)
