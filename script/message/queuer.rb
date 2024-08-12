#!/usr/bin/env ruby

require 'bundler/setup'
require 'outboxer'
require 'securerandom'

if ARGV.empty?
  puts "Usage: #{$0} <max_messages_count>"

  exit(1)
end

max_messages_count = ARGV[0].to_i

if max_messages_count <= 0
  puts "Please provide a positive integer for max messages count."

  exit(1)
end

db_config = Outboxer::Database.config(concurrency: 1, environment: 'development')
Outboxer::Database.connect(config: db_config)

Signal.trap('INT') do
  puts 'Shutting down...'

  $queueing = false
end

$queueing = true

queued_messages_count = 0

while $queueing && queued_messages_count < max_messages_count
  messageable_id = SecureRandom.hex(3)

  Outboxer::Message.queue(messageable_type: 'Event', messageable_id: messageable_id)
  puts "queued message for Event::#{messageable_id}"

  queued_messages_count += 1
end

puts "Finished queuing #{queued_messages_count} messages."

# bundle exec ruby script/message/queuer.rb 100000
