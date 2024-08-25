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
        create_worker_thread(queue: queue, logger: logger, time: time, kernel: kernel, &block)
      end

      buffer_messages(
        queue: queue,
        buffer_size: buffer_size,
        poll_interval: poll_interval,
        logger: logger,
        time: time,
        kernel: kernel)

      worker_threads.length.times { queue.push(nil) }
      worker_threads.each(&:join)
    end

    def stop
      @publishing = false
    end

    private

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

    def buffer_messages(queue:, buffer_size:, poll_interval:, logger:, time:, kernel:)
      logger.info "Buffering up to #{buffer_size} messages every #{poll_interval}s"

      while @publishing
        begin
          buffer_remaining = buffer_size - queue.length

          if buffer_remaining > 0
            dequeued_messages = Messages.dequeue(limit: buffer_remaining)

            if !dequeued_messages.empty?
              dequeued_messages.each do |message|
                queue.push({ id: message[:id], dequeued_at: time.now.utc })
              end
            else
              last_poll_time = time.now

              while @publishing && (time.now - last_poll_time) < poll_interval
                sleep(0.1)
              end
            end
          else
            sleep(0.1)
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
