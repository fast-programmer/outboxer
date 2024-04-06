#!/usr/bin/env ruby

require 'bundler/setup'

require 'outboxer'

db_config = Outboxer::Database.config(environment: 'development')
Outboxer::Database.connect(config: db_config)

Signal.trap('INT') do
  puts 'Shutting down...';

  $backlogging = false
end

$backlogging = true

while $backlogging
  messageable_id = SecureRandom.hex(3)

  Outboxer::Message.backlog(messageable_type: 'Event', messageable_id: messageable_id)
  puts "backlogged message for Event::#{messageable_id}"
end
