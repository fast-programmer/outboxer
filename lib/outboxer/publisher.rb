module Outboxer
  module Publisher
    extend self

    class Error < StandardError; end

    def connect!(db_config:, logger: nil)
      ActiveRecord::Base.logger = logger if logger

      ActiveRecord::Base.establish_connection(db_config)
    end

    def stop!
      @running = false
    end

    class ThreadShutdown < Error; end

    def pop_message!(queue:, logger:, &block)
      outboxer_message = queue.pop
      raise ThreadShutdown if outboxer_message.nil?

      logger.debug "Processing message id: #{outboxer_message.id}"

      begin
        block.call(outboxer_message)
      rescue => exception
        logger.error "Message processing failed for id: #{outboxer_message.id}, error: #{exception}"

        Message.failed!(id: outboxer_message.id, exception: exception)

        raise
      end

      Message.published!(id: outboxer_message.id)

      logger.debug "Message processed successfully for id: #{outboxer_message.id}"
    rescue ThreadShutdown
      raise
    rescue => exception
      logger.error "Error: #{exception.class}: #{exception.message}"
    end

    def push_messages!(threads:, queue:, queue_max:, poll:, logger:)
      messages = []

      queue_remaining = queue_max - queue.length
      messages = (queue_remaining > 0) ? Outboxer::Message.unpublished!(limit: queue_remaining) : []

      if messages.empty?
        log("Sleeping for #{poll} seconds because there are no messages",
          logger: logger, threads: threads, queue: queue, messages: messages)

        sleep(poll)

        log("Slept for #{poll} seconds",
          logger: logger, threads: threads, queue: queue, messages: messages)

        return
      end

      log("Pushing #{messages.length} messages to the queue",
        logger: logger, threads: threads, queue: queue, messages: messages)

      messages.each { |message| queue.push(message) }

      log("Pushed #{messages.length} messages to the queue",
        logger: logger, threads: threads, queue: queue, messages: messages)

      if queue.length >= queue_max
        log("Sleeping for #{poll} seconds because queue length >= queue max",
          logger: logger, threads: threads, queue: queue, messages: messages)

        sleep(poll)

        log("Slept for #{poll} seconds",
          logger: logger, threads: threads, queue: queue, messages: messages)
      end
    end

    def publish!(threads_max:, queue_max:, poll:, logger: nil, &block)
      queue = Queue.new

      threads = threads_max.times.map do
        Thread.new do
          loop do
            pop_message!(queue: queue, logger: logger, &block)
          rescue ThreadShutdown
            break
          rescue Exception => exception
            logger.fatal "Critical Error: #{exception.class}: #{exception.message}"

            stop!

            break
          end
        end
      end

      @running = true

      while @running
        push_messages!(threads: threads, queue: queue, queue_max: queue_max, poll: poll, logger: logger)
      end

      threads.length.times { queue.push(nil) }
      threads.each(&:join)
    end

    def log(message, logger:, threads:, queue:, messages:)
      summary = {
        threads: threads.length,
        messages: messages.length,
        queue: queue.length
      }

      logger.debug "#{message} #{summary.to_json}"
    end
  end
end
