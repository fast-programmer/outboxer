module Outboxer
  module Publisher
    extend self

    @publishing = false

    def publish(
      buffer_size: 1000,
      poll_interval: 1,
      concurrency: 20,
      logger: Logger.new($stdout, level: Logger::INFO),
      kernel: Kernel,
      time: Time,
      &block
    )
      @publishing = true

      queue = Queue.new

      worker_threads = concurrency.times.map do
        create_worker_thread(queue: queue, logger: logger, &block)
      end

      buffer_messages(
        queue: queue,
        buffer_size: buffer_size,
        poll_interval: poll_interval,
        logger: logger,
        kernel: kernel)

      worker_threads.length.times { queue.push(nil) }
      worker_threads.each(&:join)
    end

    def stop
      @publishing = false
    end

    private

    def create_worker_thread(queue:, logger:, &block)
      Thread.new do
        loop do
          begin
            queued_message = queue.pop
            break if queued_message.nil?

            dequeued_at = queued_message[:dequeued_at]

            message = Message.publishing(id: queued_message[:id])
            logger.debug "Publishing message #{message[:id]} for " \
              "#{message[:messageable_type]}::#{message[:messageable_id]} " \
              "in #{(Time.now.utc - dequeued_at).round(3)}s"

            begin
              block.call(message)
            rescue Exception => exception
              Message.failed(id: message[:id], exception: exception)
              logger.error "Failed to publish message #{message[:id]} for " \
                "#{message[:messageable_type]}::#{message[:messageable_id]} " \
                "in #{(Time.now.utc - dequeued_at).round(3)}s"

              raise
            end

            Message.published(id: message[:id])
            logger.debug "Published message #{message[:id]} for " \
              "#{message[:messageable_type]}::#{message[:messageable_id]} " \
              "in #{(Time.now.utc - dequeued_at).round(3)}s"
          rescue StandardError => exception
            logger.error "#{exception.class}: #{exception.message} " \
              "in #{(Time.now.utc - dequeued_at).round(3)}s"

            exception.backtrace.each { |frame| logger.error frame }
          rescue Exception => exception
            logger.fatal "#{exception.class}: #{exception.message} " \
              "in #{(Time.now.utc - dequeued_at).round(3)}s"
            exception.backtrace.each { |frame| logger.error frame }

            stop

            break
          end
        end
      end
    end

    def buffer_messages(queue:, buffer_size:, poll_interval:, logger:, kernel:)
      logger.info "Buffering up to #{buffer_size} messages every #{poll_interval}s"

      while @publishing
        begin
          buffer_remaining = buffer_size - queue.length
          messages = (buffer_remaining > 0) ? Messages.dequeue(limit: buffer_remaining) : []

          messages.each do |message|
            queue.push({ id: message[:id], dequeued_at: Time.now.utc })
          end

          if messages.empty?
            kernel.sleep(poll_interval)
          elsif queue.length >= buffer_size
            kernel.sleep(poll_interval)
          end
        rescue StandardError => exception
          logger.error "#{exception.class}: #{exception.message}"
          exception.backtrace.each { |frame| logger.error frame }

          kernel.sleep(poll_interval)
        rescue Exception => exception
          logger.fatal "#{exception.class}: #{exception.message}"
          exception.backtrace.each { |frame| logger.fatal frame }

          @publishing = false
        end
      end

      logger.info "Stopped buffering messages"
    end
  end
end
