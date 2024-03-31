module Outboxer
  module Publisher
    extend self

    class Error < Outboxer::Error; end;

    @running = false

    def running?
      @running
    end

    def stop!
      @running = false
    end

    class ThreadAborted < Error; end

    def pop_message!(queue:, logger:, &block)
      outboxer_message = queue.pop
      raise ThreadAborted if outboxer_message.nil?

      logger&.debug "Processing message id: #{outboxer_message.id}"

      begin
        block.call(outboxer_message)
      rescue Exception => exception
        logger.error "Message processing failed for id: #{outboxer_message.id}, error: #{exception}"

        Message.failed!(id: outboxer_message.id, exception: exception)

        raise
      end

      Message.published!(id: outboxer_message.id)

      logger&.debug "Message processed successfully for id: #{outboxer_message.id}"
    end

    def push_messages!(threads:, queue:, queue_size:, poll_interval:, logger:, kernel:)
      messages = []

      queue_remaining = queue_size - queue.length
      messages = (queue_remaining > 0) ? Messages.queue!(limit: queue_remaining) : []

      if messages.empty?
        debug_log("Sleeping for #{poll_interval} seconds because there are no messages",
          logger: logger, threads: threads, queue: queue, messages: messages)

        kernel.sleep(poll_interval)

        debug_log("Slept for #{poll_interval} seconds",
          logger: logger, threads: threads, queue: queue, messages: messages)

        return
      end

      debug_log("Pushing #{messages.length} messages to the queue",
        logger: logger, threads: threads, queue: queue, messages: messages)

      messages.each { |message| queue.push(message) }

      debug_log("Pushed #{messages.length} messages to the queue",
        logger: logger, threads: threads, queue: queue, messages: messages)

      if queue.length >= queue_size
        debug_log("Sleeping for #{poll_interval} seconds because queue length >= queue size",
          logger: logger, threads: threads, queue: queue, messages: messages)

        kernel.sleep(poll_interval)

        debug_log("Slept for #{poll_interval} seconds",
          logger: logger, threads: threads, queue: queue, messages: messages)
      end
    end

    def publish!(thread_count: 5, queue_size: 8, poll_interval: 1,
                 logger: nil, kernel: Kernel, &block)
      config = { thread_count: thread_count, queue_size: queue_size, poll_interval: poll_interval }
      logger&.info "Starting publisher #{config}"

      @running = true
      queue = Queue.new

      trap('INT') { Publisher.stop! }

      logger&.info "Creating #{thread_count} worker threads"

      threads = thread_count.times.map do
        Thread.new do
          loop do
            begin
              pop_message!(queue: queue, logger: logger, &block)
            rescue ThreadAborted
              logger&.info 'Thread shutting down'

              break
            rescue => exception
              logger.error "#{exception.class}: #{exception.message}"
            rescue Exception => exception
              logger.fatal "#{exception.class}: #{exception.message}"

              stop!

              break
            end
          end

          logger&.info 'Thread shut down gracefully'
        end
      end

      logger&.info "Created #{thread_count} worker threads"

      logger&.info 'Publishing messages...'

      while @running
        begin
          push_messages!(
            threads: threads,
            queue: queue,
            queue_size: queue_size,
            poll_interval: poll_interval,
            logger: logger,
            kernel: Kernel)
        rescue => exception
          logger.error "#{exception.class}: #{exception.message}"
        rescue Exception => exception
          logger.fatal ("#{exception.class}: #{exception.message}")

          stop!
        end
      end

      logger&.info "Publisher shutting down..."

      threads.length.times { queue.push(nil) }
      threads.each(&:join)

      logger&.info "Publisher shut down gracefully"
    end

    def debug_log(message, logger:, threads:, queue:, messages:)
      queue = {
        messages: messages.length,
        queue: queue.length,
        threads: threads.length }

      logger&.debug "#{message} | queue: #{queue.to_json}"
    end

    private_class_method :debug_log
  end
end
