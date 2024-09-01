module Outboxer
  module SingleThreadedPublisher
    extend self

    @publishing = false

    def publish(
      batch_size: 200, poll_interval: 0.1,
      logger: Logger.new($stdout, level: Logger::INFO),
      kernel: Kernel,
      time: Time,
      &block
    )
      @publishing = true

      dequeue_messages(
        batch_size: batch_size,
        poll_interval: poll_interval,
        logger: logger,
        time: time,
        kernel: kernel,
        &block)
    end

    def stop
      @publishing = false
    end

    private

    def process_message(queued_message:, logger:, time:, kernel:, &block)
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
    end

    def sleep(duration, poll_interval: 0.1, start_time: Time.now, time: Time, kernel: Kernel)
      while @publishing && (time.now - start_time) < duration
        kernel.sleep(poll_interval)
      end
    end

    def dequeue_messages(batch_size:, poll_interval:,
                         logger:, time:, kernel:, &block)
      logger.info "Dequeueing up to #{batch_size} messages every #{poll_interval} second(s)"

      while @publishing
        begin
          dequeued_messages = Messages.dequeue(limit: batch_size)

          dequeued_messages.each do |message|
            process_message(
              queued_message: { id: message[:id], dequeued_at: time.now.utc },
              logger: logger, time: time, kernel: kernel,
              &block)
          end

          if dequeued_messages.size < batch_size
            Publisher.sleep(poll_interval, time: time, kernel: kernel)
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

      logger.info "Stopped polling database"
    end
  end
end
