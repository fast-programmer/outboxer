require 'thread'
require 'securerandom'

queue = Queue.new

def start_worker_thread(queue, thread_id)
  Thread.new do
    while true
      item = queue.pop
      break if item == :shutdown
      puts "Thread #{thread_id} processing item: #{item}"

      sleep(1)
    end
    puts "Thread #{thread_id} shutting down."
  end
end

workers = 5.times.map { |i| start_worker_thread(queue, i+1) }

Signal.trap("INT") do
  puts "Signal interrupt received, shutting down..."
  5.times { queue.push(:shutdown) }
  workers.each(&:join)
  puts "All worker threads have been shut down."
  exit
end

100.times { queue.push(SecureRandom.hex(4)) }

while true
  10.times do
    item = SecureRandom.hex(4)
    puts "Main thread pushing item: #{item}"
    queue.push(item)
  end

  sleep(5)
end
