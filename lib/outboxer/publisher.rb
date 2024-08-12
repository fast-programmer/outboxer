module Outboxer
  module Publisher
    extend self

    @publishing = false

    def publish(
      queue: Queue.new,
      queue_max: 10,
      concurrency: 5,
      poll_interval: 1,
      logger: Logger.new($stdout, level: Logger::INFO),
      kernel: Kernel,
      time: Time,
      &block
    )
      @publishing = true

      worker_threads = concurrency.times.map do
        create_worker_thread(queue: queue, logger: logger, &block)
      end

      dequeue_messages(
        queue: queue,
        queue_max: queue_max,
        poll_interval: poll_interval,
        logger: logger,
        kernel: kernel)

      worker_threads.length.times { queue.push(nil) }
      worker_threads.each(&:join)
    end

    def stop
      @publishing = false
    end

    def create_worker_thread(queue:, logger:, &block)
      Thread.new do
        loop do
          begin
            queued_message = queue.pop
            break if queued_message.nil?

            dequeued_at = queued_message[:dequeued_at]

            message = Message.publishing(id: queued_message[:id])
            logger.info "Publishing message #{message[:id]} for " \
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
            logger.info "Published message #{message[:id]} for " \
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

            @stopped = true

            break
          end
        end
      end
    end

    def dequeue_messages(queue:, queue_max:, poll_interval:, logger:, kernel:)
      logger.info "Dequeuing up to #{queue_max} messages every #{poll_interval}s"

      while @publishing
        begin
          messages = []

          queue_remaining = queue_max - queue.length
          queue_stats = { total: queue, remaining: queue_remaining, current: queue.length }
          logger.debug "Queue: #{queue_stats}"

          logger.debug "Connection pool: #{ActiveRecord::Base.connection_pool.stat}"

          messages = (queue_remaining > 0) ? Messages.dequeue(limit: queue_remaining) : []
          logger.debug "Updated #{messages.length} messages from queued to dequeued"

          messages.each do |message|
            logger.info "Dequeued message #{message[:id]} for " \
              "#{message[:messageable_type]}::#{message[:messageable_id]}"

            queue.push({ id: message[:id], dequeued_at: Time.now.utc })
          end

          logger.debug "Pushed #{messages.length} messages to queue."

          if messages.empty?
            logger.debug "Sleeping for #{poll_interval} seconds because no messages were queued..."

            kernel.sleep(poll_interval)
          elsif queue.length >= queue_max
            logger.debug "Sleeping for #{poll_interval} seconds because queue was full..."

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

      logger.info "Stopped dequeuing messages"
    end
  end
end
