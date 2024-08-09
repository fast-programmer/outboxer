module Outboxer
  module Publisher
    extend self

    @publishing = false

    def publish(
      queue: Queue.new,
      max_queue_size: 10,
      num_publisher_threads: 5,
      poll_interval: 1,
      metrics_statsd: nil,
      metrics_submit_interval: 30,
      metrics_tags: [],
      logger: Logger.new($stdout, level: Logger::INFO),
      kernel: Kernel,
      time: Time,
      &block
    )
      @publishing = true

      submit_messages_metrics_thread = create_submit_messages_metrics_thread(
        statsd: metrics_statsd, submit_interval: metrics_submit_interval, tags: [],
        logger: logger, kernel: kernel, time: time) unless metrics_statsd.nil?

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

      submit_messages_metrics_thread.join unless metrics_statsd.nil?
    end

    def stop
      @publishing = false
    end

    def create_submit_messages_metrics_thread(statsd:, submit_interval:, tags:,
                                              logger:, kernel:, time:)
      Thread.new do
        last_submitted_at = time.now.utc

        while @publishing
          begin
            if time.now.utc - last_submitted_at >= submit_interval
              messages_metrics = Messages.collect_metrics

              statsd.batch do
                messages_metrics.each do |status, message_metrics|
                  logger.info "Submitting messages metrics for #{status} messages: "\
                              "count=#{message_metrics[:count]}, "\
                              "latency=#{message_metrics[:latency]}"

                  statsd.gauge(
                    "outboxer.messages.#{status}.count", message_metrics[:count], tags: tags)

                  statsd.gauge(
                    "outboxer.messages.#{status}.latency", message_metrics[:latency], tags: tags)

                  logger.info "Submitted messages metrics for #{status} messages: "\
                    "count=#{message_metrics[:count]}, "\
                    "latency=#{message_metrics[:latency]}"
                end
              end

              last_submitted_at = time.now.utc
            end
          rescue StandardError => e
            logger.error "Failed to submit messages metrics: #{e.class}: #{e.message}"

            e.backtrace.each { |frame| logger.error frame }
          end

          kernel.sleep(1)
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
          elsif queue.length >= max_queue_size
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
