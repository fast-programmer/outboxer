require 'thread'
require 'logger'
require 'optparse'

options = {
  threads_max: 5,
  queue_size: 10,
  poll_interval: 1
}

OptionParser.new do |opts|
  opts.banner = "Usage: concurrent_publisher.rb [options]"

  opts.on("-t", "--threads NUMBER", Integer, "Number of worker threads") do |max|
    options[:threads_max] = max
  end

  opts.on("-q", "--queue SIZE", Integer, "Size of the message queue") do |size|
    options[:queue] = size
  end

  opts.on("-p", "--poll INTERVAL", Integer, "Polling interval in seconds") do |interval|
    options[:poll_interval] = interval
  end
end.parse!

THREADS = options[:threads_max]
QUEUE_MAX = options[:queue_max]
POLL_INTERVAL = options[:poll_interval]

logger = Logger.new(STDOUT)

queue = Queue.new
threads = []
running = true

def publish_message!(outboxer_message)
  case outboxer_message.outboxer_messageable_type
  when 'Event'
    EventHandlerWorker.perform_async({ 'id' => outboxer_message.outboxer_messageable_id })
  end
end

Signal.trap('INT') do
  running = false

  MAX_THREADS.times { queue.push(nil) }
end

MAX_THREADS.times do
  threads << Thread.new do
    while running
      begin
        outboxer_message = queue.pop
        break if outboxer_message.nil?

        begin
          publish_message!(outboxer_message)
        rescue => exception
          Outboxer::Message.failed!(id: outboxer_message.id, exception: exception)

          raise
        end

        Outboxer::Message.published!(id: outboxer_message.id)
      rescue => exception
        logger.error "Error: #{exception.class}: #{exception.message}"
      end
    end
  end
end

while running
  begin
    limit = QUEUE_SIZE_MAX - queue.size # 8 - 4

    messages = (limit > 0) ? Outboxer::Message.unpublished!(limit: limit) : []

    if !messages.empty?
      messages.each { |message| queue.push(message) }
    else
      sleep POLL
    end
  rescue => exception
    logger.error "Error: #{exception.class}: #{exception.message}"
  end
end

while !queue.empty?
  sleep ERROR_POLL
end

threads.each(&:join)
