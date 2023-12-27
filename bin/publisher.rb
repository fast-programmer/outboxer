require 'optparse'
require 'logger'

options = { concurrency: 5, poll: 1 }

OptionParser.new do |opts|
  opts.banner = "Usage: publisher.rb [options]"

  opts.on("-t", "--concurrency NUMBER", Integer, "Number of worker threads") do |max|
    options[:threads_max] = max
  end

  opts.on("-p", "--poll INTERVAL", Integer, "Number of seconds to wait when no results or queue is at capacity") do |interval|
    options[:poll_interval] = interval
  end
end.parse!

publisher = Outboxer::Publisher.new(
  concurrency: options[:concurrency], poll: options[:poll], logger: Logger.new(STDOUT))

Signal.trap('INT') { publisher.stop! }

publisher.publish! do |outboxer_message|
  case outboxer_message.outboxer_messageable_type
  when 'Event'
    EventHandlerWorker.perform_async({ 'id' => outboxer_message.outboxer_messageable_id })
  end
end
