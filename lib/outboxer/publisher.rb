module Outboxer
  module Publisher
    extend self

    @publishing = false

    def publish(
      buffer_size: 1000,
      buffer_poll_interval: 0.1, database_poll_interval: 1,
      concurrency: 20,
      logger: Logger.new($stdout, level: Logger::INFO),
      kernel: Kernel,
      time: Time,
      &block
    )
      @publishing = true

      queue = Queue.new

      worker_threads = concurrency.times.map do
        create_worker_thread(queue: queue, logger: logger, time: time, kernel: kernel, &block)
      end

      buffer_messages(
        queue: queue,
        buffer_size: buffer_size,
        buffer_poll_interval: buffer_poll_interval,
        database_poll_interval: database_poll_interval,
        logger: logger,
        time: time,
        kernel: kernel)

      worker_threads.length.times { queue.push(nil) }
      worker_threads.each(&:join)
    end

    def stop
      @publishing = false
    end

    # private

    def create_worker_thread(queue:, logger:, time:, kernel:, &block)
      Thread.new do
        loop do
          begin
            queued_message = queue.pop
            break if queued_message.nil?

            dequeued_at = queued_message[:dequeued_at]

            message = Message.publishing(id: queued_message[:id])
            logger.debug "Publishing message #{message[:id]} for " \
              "#{message[:messageable_type]}::#{message[:messageable_id]} " \
              "in #{(time.now.utc - dequeued_at).round(3)}s"

            begin
              block.call(message)
            rescue Exception => exception
              Message.failed(id: message[:id], exception: exception)
              logger.error "Failed to publish message #{message[:id]} for " \
                "#{message[:messageable_type]}::#{message[:messageable_id]} " \
                "in #{(time.now.utc - dequeued_at).round(3)}s"

              raise
            end

            Message.published(id: message[:id])
            logger.debug "Published message #{message[:id]} for " \
              "#{message[:messageable_type]}::#{message[:messageable_id]} " \
              "in #{(time.now.utc - dequeued_at).round(3)}s"
          rescue StandardError => exception
            logger.error "#{exception.class}: #{exception.message} " \
              "in #{(time.now.utc - dequeued_at).round(3)}s"

            exception.backtrace.each { |frame| logger.error frame }
          rescue Exception => exception
            logger.fatal "#{exception.class}: #{exception.message} " \
              "in #{(time.now.utc - dequeued_at).round(3)}s"
            exception.backtrace.each { |frame| logger.error frame }

            stop

            break
          end
        end
      end
    end

    def sleep(duration, poll_interval: 0.1, start_time: Time.now, time: Time, kernel: Kernel)
      while @publishing && (time.now - start_time) < duration
        kernel.sleep(poll_interval)
      end
    end

    def buffer_messages(queue:, buffer_size:,
                        buffer_poll_interval:, database_poll_interval:,
                        logger:, time:, kernel:)
      logger.info "Buffering up to #{buffer_size} messages every #{buffer_poll_interval}s"
      logger.info "Polling database every #{database_poll_interval}s"

      while @publishing
        begin
          buffer_remaining = buffer_size - queue.length

          if buffer_remaining > 0
            dequeued_messages = Messages.dequeue(limit: buffer_remaining)

            if dequeued_messages.count > 0
              dequeued_messages.each do |message|
                queue.push({ id: message[:id], dequeued_at: time.now.utc })
              end
            else
              Publisher.sleep(database_poll_interval)
            end
          else
            Publisher.sleep(buffer_poll_interval)
          end
        rescue StandardError => exception
          logger.error "#{exception.class}: #{exception.message}"
          exception.backtrace.each { |frame| logger.error frame }
        rescue Exception => exception
          logger.fatal "#{exception.class}: #{exception.message}"
          exception.backtrace.each { |frame| logger.fatal frame }

          stop
        end
      end

      logger.info "Stopped buffering messages"
    end
  end
end
