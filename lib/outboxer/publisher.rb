module Outboxer
  module Publisher
    extend self

    module Status
      PAUSED = :paused
      PUBLISHING = :publishing
      TERMINATING = :terminating
    end

    STATUSES = [Status::PAUSED, Status::PUBLISHING, Status::TERMINATING]
    @status = Status::PAUSED

    Signal.trap("TERM") { terminate }
    Signal.trap("INT")  { terminate }
    Signal.trap("TSTP") { pause }
    Signal.trap("CONT") { resume }

    def terminate
      @status = Status::TERMINATING
    end

    def pause
      @status = Status::PAUSED
    end

    def resume
      @status = Status::PUBLISHING
    end

    # :nocov:
    def sleep(duration, start_time:, tick_interval:, process:, kernel:)
      while (@status != Status::TERMINATING) &&
          (process.clock_gettime(process::CLOCK_MONOTONIC) - start_time) < duration
        kernel.sleep(tick_interval)
      end
    end
    # :nocov:

    def publish(
      batch_size: 200, poll_interval: 5, tick_interval: 0.1, concurrency: 1,
      logger: Logger.new($stdout, level: Logger::INFO),
      time: Time, process: ::Process, kernel: Kernel,
      &block
    )
      logger.info "Outboxer v#{Outboxer::VERSION} publishing in ruby #{RUBY_VERSION} "\
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      logger.info "Outboxer config "\
        "{ batch_size: #{batch_size}, poll_interval: #{poll_interval}, concurrency: #{concurrency} }"

      @status = Status::PUBLISHING

      queue = Queue.new

      threads = concurrency.times.map do
        Thread.new do
          while (message = queue.pop)
            break if message.nil?

            publish_message(dequeued_message: message, logger: logger, time: time, kernel: kernel, &block)
          end
        end
      end

      while @status != Status::TERMINATING
        case @status
        when Status::PUBLISHING
          begin
            dequeue_limit = batch_size - queue.size

            if dequeue_limit > 0
              dequeued_messages = Messages.dequeue(limit: dequeue_limit)

              if dequeued_messages.count > 0
                dequeued_messages.each { |message| queue.push(message) }
              else
                Publisher.sleep(
                  poll_interval,
                  start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
                  tick_interval: tick_interval,
                  process: process, kernel: kernel)
              end
            else
              Publisher.sleep(
                tick_interval,
                start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
                tick_interval: tick_interval,
                process: process, kernel: kernel)
            end
          rescue StandardError => exception
            logger.error "#{exception.class}: #{exception.message}"
            exception.backtrace.each { |frame| logger.error frame }
          rescue Exception => exception
            logger.fatal "#{exception.class}: #{exception.message}"
            exception.backtrace.each { |frame| logger.fatal frame }

            terminate
          end
        when Status::PAUSED
          Publisher.sleep(
            tick_interval,
            start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
            tick_interval: tick_interval,
            process: process, kernel: kernel)
        end
      end

      logger.info "Outboxer terminating"
      concurrency.times { queue.push(nil) }
      threads.each(&:join)
      logger.info "Outboxer terminated"
    end

    def publish_message(dequeued_message:, logger:, time:, kernel:, &block)
      dequeued_at = dequeued_message[:updated_at]

      message = Message.publishing(id: dequeued_message[:id])
      logger.debug "Outboxer publishing message #{message[:id]} for "\
        "#{message[:messageable_type]}::#{message[:messageable_id]} "\
        "in #{(time.now.utc - dequeued_at).round(3)}s"

      begin
        block.call(message)
      rescue Exception => exception
        Message.failed(id: message[:id], exception: exception)
        logger.error "Outboxer failed to publish message #{message[:id]} for "\
          "#{message[:messageable_type]}::#{message[:messageable_id]} "\
          "in #{(time.now.utc - dequeued_at).round(3)}s"

        raise
      end

      Message.published(id: message[:id])
      logger.debug "Outboxer published message #{message[:id]} for "\
        "#{message[:messageable_type]}::#{message[:messageable_id]} "\
        "in #{(time.now.utc - dequeued_at).round(3)}s"
    rescue StandardError => exception
      logger.error "#{exception.class}: #{exception.message} "\
        "in #{(time.now.utc - dequeued_at).round(3)}s"
      exception.backtrace.each { |frame| logger.error frame }
    rescue Exception => exception
      logger.fatal "#{exception.class}: #{exception.message} "\
        "in #{(time.now.utc - dequeued_at).round(3)}s"
      exception.backtrace.each { |frame| logger.fatal frame }

      terminate
    end
  end
end
