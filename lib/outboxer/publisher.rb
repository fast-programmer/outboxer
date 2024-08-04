module Outboxer
  module Publisher
    extend self

    @publishing = false

    def publish(
      queue: Queue.new,
      max_queue_size: 10,
      num_publisher_threads: 5,
      poll_interval: 1,
      statsd: nil,
      reporting_interval: 1,
      logger: Logger.new($stdout, level: Logger::INFO),
      kernel: Kernel,
      &block
    )
      @publishing = true

      reporting_thread = create_reporting_thread(
        statsd: statsd, reporting_interval: reporting_interval) unless statsd.nil?

      publisher_threads = num_publisher_threads.times.map do
        create_publisher_thread(queue: queue, logger: logger, &block)
      end

      dequeue_messages(
        queue: queue,
        max_queue_size: max_queue_size,
        poll_interval: poll_interval,
        logger: logger,
        kernel: kernel)

      publisher_threads.length.times { queue.push(nil) }
      publisher_threads.each(&:join)

      reporting_thread.join
    end

    def stop
      @publishing = false
    end

    def create_reporting_thread(statsd:, reporting_interval:)
      Thread.new do
        last_updated_utc_time = Time.now.utc

        while @publishing
          current_utc_time = Time.now.utc

          if current_utc_time - last_updated_utc_time >= reporting_interval
            Messages.report_statsd_gauges(
              statsd: statsd,
              reporting_interval: reporting_interval,
              current_utc_time: current_utc_time)

            last_updated_utc_time = current_utc_time
          end

          sleep 1
        end
      end
    end

    def create_publisher_thread(queue:, logger:, &block)
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

    def dequeue_messages(queue:, max_queue_size:, poll_interval:, logger:, kernel:)
      logger.info "Dequeuing up to #{max_queue_size} messages every #{poll_interval}s"

      while @publishing
        begin
          messages = []

          queue_remaining = max_queue_size - queue.length
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
          elsif queue.length >= queue
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
