#!/usr/bin/env ruby

require 'bundler/setup'

require 'outboxer'

db_config = Outboxer::Database.config(environment: 'development')
Outboxer::Database.connect(config: db_config)

Signal.trap('INT') do
  puts 'Shutting down...';

  $queueing = false
end

$queueing = true

while $queueing
  messageable_id = SecureRandom.hex(3)

  Outboxer::Message.queue(messageable_type: 'Event', messageable_id: messageable_id)
  puts "queued message for Event::#{messageable_id}"

  # sleep(rand(0.1..1.0))
end
