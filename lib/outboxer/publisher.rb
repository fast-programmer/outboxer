module Outboxer
  module Publisher
    extend self

    @publishing = false

    def stop
      @publishing = false
    end

    # :nocov:
    def sleep(duration, start_time:, tick_interval:, time:, kernel:)
      while @publishing && (time.now - start_time) < duration
        kernel.sleep(tick_interval)
      end
    end
    # :nocov:

    def publish(
      batch_size: 200, poll_interval: 5, tick_interval: 1,
      logger: Logger.new($stdout, level: Logger::INFO),
      time: Time, kernel: Kernel,
      &block
    )
      logger.info "Outboxer dequeueing messages " \
        "{ batch_size: #{batch_size}, poll_interval: #{poll_interval}, " \
        "tick_interval: #{tick_interval} }"

      @publishing = true

      while @publishing
        begin
          dequeued_messages = Messages.dequeue(limit: batch_size)

          dequeued_messages.each do |dequeued_message|
            publish_message(
              dequeued_message: dequeued_message, logger: logger, time: time, kernel: kernel, &block)
          end

          if dequeued_messages.count < batch_size
            Publisher.sleep(
              poll_interval, start_time: time.now, tick_interval: tick_interval,
              time: time, kernel: kernel)
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

      logger.info "Outboxer stopped dequeueing messages"
    end

    def publish_message(dequeued_message:, logger:, time:, kernel:, &block)
      dequeued_at = dequeued_message[:updated_at]

      message = Message.publishing(id: dequeued_message[:id])
      logger.debug "Outboxer publishing message #{message[:id]} for " \
        "#{message[:messageable_type]}::#{message[:messageable_id]} " \
        "in #{(time.now.utc - dequeued_at).round(3)}s"

      begin
        block.call(message)
      rescue Exception => exception
        Message.failed(id: message[:id], exception: exception)
        logger.error "Outboxer failed to publish message #{message[:id]} for " \
          "#{message[:messageable_type]}::#{message[:messageable_id]} " \
          "in #{(time.now.utc - dequeued_at).round(3)}s"

        raise
      end

      Message.published(id: message[:id])
      logger.debug "Outboxer published message #{message[:id]} for " \
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
  end
end
