module Outboxer
  module Publisher
    extend self

    class Error < StandardError; end

    @running = false

    def running?
      @running
    end

    def stop!
      @running = false
    end

    class ConnectError < Error; end

    def connect!(db_config:, logger: nil)
      ActiveRecord::Base.logger = logger if logger

      ActiveRecord::Base.establish_connection(db_config)

      ActiveRecord::Base.connection_pool.with_connection {}
    rescue ActiveRecord::DatabaseConnectionError => error
      raise ConnectError.new(error.message)
    end

    def connected?
      ActiveRecord::Base.connected?
    end

    class DisconnectError < Error; end

    def disconnect!
      ActiveRecord::Base.connection_handler.clear_active_connections!
      ActiveRecord::Base.connection_handler.connection_pool_list.each(&:disconnect!)
    rescue => error
      raise DisconnectError.new(error.message)
    end

    class ThreadShutdown < Error; end

    def pop_message!(queue:, logger:, &block)
      outboxer_message = queue.pop
      raise ThreadShutdown if outboxer_message.nil?

      logger.debug "Processing message id: #{outboxer_message.id}"

      begin
        block.call(outboxer_message)
      rescue Exception => exception
        logger.error "Message processing failed for id: #{outboxer_message.id}, error: #{exception}"

        Message.failed!(id: outboxer_message.id, exception: exception)

        raise
      end

      Message.published!(id: outboxer_message.id)

      logger.debug "Message processed successfully for id: #{outboxer_message.id}"
    end

    def push_messages!(threads:, queue:, queue_max:, poll:, logger:, kernel:)
      messages = []

      queue_remaining = queue_max - queue.length
      messages = (queue_remaining > 0) ? Outboxer::Message.unpublished!(limit: queue_remaining) : []

      if messages.empty?
        debug_log("Sleeping for #{poll} seconds because there are no messages",
          logger: logger, threads: threads, queue: queue, messages: messages)

        kernel.sleep(poll)

        debug_log("Slept for #{poll} seconds",
          logger: logger, threads: threads, queue: queue, messages: messages)

        return
      end

      debug_log("Pushing #{messages.length} messages to the queue",
        logger: logger, threads: threads, queue: queue, messages: messages)

      messages.each { |message| queue.push(message) }

      debug_log("Pushed #{messages.length} messages to the queue",
        logger: logger, threads: threads, queue: queue, messages: messages)

      if queue.length >= queue_max
        debug_log("Sleeping for #{poll} seconds because queue length >= queue max",
          logger: logger, threads: threads, queue: queue, messages: messages)

        kernel.sleep(poll)

        debug_log("Slept for #{poll} seconds",
          logger: logger, threads: threads, queue: queue, messages: messages)
      end
    end

    def publish!(threads_max:, queue_max:, poll:, logger: nil, kernel: Kernel, &block)
      @running = true
      queue = Queue.new

      threads = threads_max.times.map do
        Thread.new do
          loop do
            begin
              pop_message!(queue: queue, logger: logger, &block)
            rescue ThreadShutdown
              break
            rescue => exception
              logger.error "#{exception.class}: #{exception.message}"
            rescue Exception => exception
              logger.fatal "#{exception.class}: #{exception.message}"

              stop!

              break
            end
          end
        end
      end

      while @running
        begin
          push_messages!(
            threads: threads,
            queue: queue,
            queue_max: queue_max,
            poll: poll,
            logger: logger,
            kernel: Kernel)
        rescue => exception
          logger.error "#{exception.class}: #{exception.message}"
        rescue Exception => exception
          logger.fatal ("#{exception.class}: #{exception.message}")

          stop!
        end
      end

      threads.length.times { queue.push(nil) }
      threads.each(&:join)
    end

    def debug_log(message, logger:, threads:, queue:, messages:)
      summary = {
        threads: threads.length,
        messages: messages.length,
        queue: queue.length
      }

      logger.debug "#{message} #{summary.to_json}"
    end
  end
end
