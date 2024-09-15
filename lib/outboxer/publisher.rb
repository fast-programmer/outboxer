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
    @queue = Queue.new

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

    def sleep(duration, start_time:, tick_interval:, time:, kernel:)
      while @status != Status::TERMINATING && (time.now - start_time) < duration
        kernel.sleep(tick_interval)
      end
    end

    def publish(
      batch_size: 200, poll_interval: 5, tick_interval: 0.1, num_worker_threads: 1,
      logger: Logger.new($stdout, level: Logger::INFO),
      time: Time, kernel: Kernel, &block
    )
      logger.info "Outboxer v#{Outboxer::VERSION} publishing in ruby #{RUBY_VERSION} " \
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      logger.info "Outboxer dequeueing { batch_size: #{batch_size}, poll_interval: #{poll_interval}, " \
        "workers: #{num_worker_threads} }"
      @status = Status::PUBLISHING

      worker_threads = num_worker_threads.times.map do
        Thread.new do
          while (message = @queue.pop)
            break if message.nil?
            publish_message(dequeued_message: message, logger: logger, time: time, kernel: kernel, &block)
          end
        end
      end

      while @status != Status::TERMINATING
        case @status
        when Status::PUBLISHING
          begin
            dequeued_messages = Messages.dequeue(limit: batch_size, logger: logger)
            dequeued_messages.each do |msg|
              while @queue.size >= batch_size
                Publisher.sleep(tick_interval, start_time: time.now, tick_interval: tick_interval,
                                time: time, kernel: kernel)
              end
              @queue.push(msg)
            end
            if dequeued_messages.count < batch_size
              Publisher.sleep(poll_interval, start_time: time.now, tick_interval: tick_interval,
                              time: time, kernel: kernel)
            end
          rescue StandardError => e
            logger.error "#{e.class}: #{e.message}"
            e.backtrace.each { |frame| logger.error frame }
          rescue Exception => e
            logger.fatal "#{e.class}: #{e.message}"
            e.backtrace.each { |frame| logger.fatal frame }
            terminate
          end
        when Status::PAUSED
          Publisher.sleep(poll_interval, start_time: time.now, tick_interval: tick_interval,
                          time: time, kernel: kernel)
        end
      end

      num_worker_threads.times { @queue.push(nil) }
      worker_threads.each(&:join)
      logger.info "Outboxer stopped dequeueing messages"
    end

    def publish_message(dequeued_message:, logger:, time:, kernel:, &block)
      dequeued_at = dequeued_message[:updated_at]
      message = Message.publishing(id: dequeued_message[:id])
      logger.debug "Outboxer publishing message #{message[:id]} in #{(time.now.utc - dequeued_at).round(3)}s"

      begin
        block.call(message)
      rescue Exception => e
        Message.failed(id: message[:id], exception: e)
        logger.error "Outboxer failed to publish message #{message[:id]} in #{(time.now.utc - dequeued_at).round(3)}s"
        raise
      end

      Message.published(id: message[:id])
      logger.debug "Outboxer published message #{message[:id]} in #{(time.now.utc - dequeued_at).round(3)}s"
    rescue StandardError => e
      logger.error "#{e.class}: #{e.message} in #{(time.now.utc - dequeued_at).round(3)}s"
      e.backtrace.each { |frame| logger.error frame }
    rescue Exception => e
      logger.fatal "#{e.class}: #{e.message} in #{(time.now.utc - dequeued_at).round(3)}s"
      e.backtrace.each { |frame| logger.fatal frame }
      terminate
    end
  end
end
