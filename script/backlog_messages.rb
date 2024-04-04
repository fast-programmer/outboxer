require 'bundler/setup'

require 'thread'
require 'set'

require 'outboxer'

num_threads = 5
used_ids = Set.new
mutex = Mutex.new

db_config = Outboxer::Database.config(environment: 'development')
Outboxer::Database.connect!(config: db_config)

Signal.trap('INT') do
  puts 'Shutting down...';

  exit
end

threads = num_threads.times.map do
  Thread.new do
    loop do
      messageable_id = rand(1..100_000)
      next if mutex.synchronize { !used_ids.add?(messageable_id).nil? }

      Outboxer::Message.backlog!(messageable_type: 'Event', messageable_id: messageable_id)
      puts "backlogged message for Event::#{messageable_id}"

      sleep rand
    end
  end
end

threads.each(&:join)
puts "All tasks completed."
