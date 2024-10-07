module Outboxer
  module Publisher
    extend self

    @trapped_signal = nil

    Signal.trap("TERM") { @trapped_signal = :term }
    Signal.trap("INT")  { @trapped_signal = :int }
    Signal.trap("TSTP") { @trapped_signal = :tstp }
    Signal.trap("CONT") { @trapped_signal = :cont }
    Signal.trap("TTIN") { @trapped_signal = :ttin }

    def start(name:, current_time:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.create!(
            name: name, status: Status::PUBLISHING, next_status: nil, info: {},
            created_at: current_time, updated_at: current_time)

          publisher.id
        end
      end
    end

    def pause_async(id:, logger:, current_time:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock('FOR UPDATE NOWAIT').find_by!(id: id)

          if publisher.status != Status::PUBLISHING
            raise ArgumentError, "status must be #{Status::PUBLISHING}"
          end

          publisher.update!(next_status: Status::PAUSED, updated_at: current_time)
        end
      end
    end

    def resume_async(id:, logger:, current_time:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock('FOR UPDATE NOWAIT').find_by!(id: id)

          if publisher.status != Status::PAUSED
            raise ArgumentError, "status must be #{Status::PAUSED}"
          end

          publisher.update!(next_status: Status::PUBLISHING, updated_at: current_time)
        end
      end
    end

    def terminate_async(id:, logger:, current_time:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock('FOR UPDATE NOWAIT').find_by!(id: id)
          publisher.update!(next_status: Status::TERMINATING, updated_at: current_time)
        end
      end
    end

    def terminated(id:, logger:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock('FOR UPDATE NOWAIT').find_by!(id: id)

          if publisher.status != Status::TERMINATING
            raise ArgumentError, "status must be #{Status::TERMINATING}"
          end

          publisher.destroy!
        end
      end
    end

    def update_status(id:, logger:, current_time:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock('FOR UPDATE NOWAIT').find_by!(id: id)

          if !publisher.next_status.nil?
            publisher.update!(status: publisher.next_status, next_status: nil, updated_at: current_time)
          end

          publisher
        end
      end
    end

    # :nocov:
    def sleep(duration, start_time:, tick_interval:, process:, kernel:)
      while (@status != Status::TERMINATING) &&
          (process.clock_gettime(process::CLOCK_MONOTONIC) - start_time) < duration
        kernel.sleep(tick_interval)
      end
    end
    # :nocov:

    def create_trap_signal_thread(id:, interval:, tick_interval:, logger:,
                                  time:, process:, kernel:)
      Thread.new do
        while @status != Status::TERMINATING
          if !@trapped_signal.nil?
            case @trapped_signal
            when :term
              terminate_async(id: id, logger: logger, current_time: time.now)

              publisher = Publisher.update_status(id: id, logger: logger, current_time: time.now)

              @status = publisher.status
            when :int
              terminate_async(id: id, logger: logger, current_time: time.now)

              publisher = Publisher.update_status(id: id, logger: logger, current_time: time.now)

              @status = publisher.status
            when :tstp
              pause_async(id: id, logger: logger, current_time: time.now)

              publisher = Publisher.update_status(id: id, logger: logger, current_time: time.now)

              @status = publisher.status
            when :cont
              resume_async(id: id, logger: logger, current_time: time.now)

              publisher = Publisher.update_status(id: id, logger: logger, current_time: time.now)

              @status = publisher.status
            when :ttin
              Thread.list.each_with_index do |thread, index|
                logger.info thread.backtrace.join("\n") if thread.backtrace
              end
            end

            @trapped_signal = nil
          end

          Publisher.sleep(
            interval,
            start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
            tick_interval: tick_interval,
            process: process, kernel: kernel)
        end
      end
    end

    def create_publisher_threads(queue:, concurrency:, logger:, time:, kernel:, &block)
      concurrency.times.map do
        Thread.new do
          while (message = queue.pop)
            break if message.nil?

            publish_message(dequeued_message: message, logger: logger, time: time, kernel: kernel, &block)
          end
        end
      end
    end

    def dequeue_messages(id:, queue:, batch_size:, poll_interval: , tick_interval:, logger:,
                         process:, kernel:)
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

      terminate(id: id, logger: logger)
    end

    @status = nil

    Status = Models::Publisher::Status

    def create_update_status_thread(id:, interval:, tick_interval:, logger:,
                                    time:, process:, kernel:)
      Thread.new do
        while @status != Status::TERMINATING
          publisher = Publisher.update_status(id: id, logger: logger, current_time: time.now)

          @status = publisher.status

          Publisher.sleep(
            interval,
            start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
            tick_interval: tick_interval,
            process: process, kernel: kernel)
        end
      end
    end

    def publish(
      batch_size: 100, concurrency: 1,
      poll_interval: 5, tick_interval: 0.1, signal_interval: 1, status_interval: 1,
      logger: Logger.new($stdout, level: Logger::INFO),
      time: ::Time, socket: ::Socket, process: ::Process, kernel: ::Kernel,
      &block
    )
      logger.info "Outboxer v#{Outboxer::VERSION} publishing in ruby #{RUBY_VERSION} "\
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      logger.info "Outboxer config {"\
        " batch_size: #{batch_size}, concurrency: #{concurrency},"\
        " poll_interval: #{poll_interval}, tick_interval: #{tick_interval},"\
        " signal_interval: #{signal_interval}, status_interval: #{status_interval} }"

      queue = Queue.new
      @status = Status::PUBLISHING

      id = start(name: "#{socket.gethostname}:#{process.pid}", current_time: time.now)

      publisher_threads = create_publisher_threads(
        queue: queue,
        concurrency: concurrency,
        logger: logger,
        time: time,
        kernel: kernel)

      trap_signal_thread = create_trap_signal_thread(
        id: id,
        interval: signal_interval,
        tick_interval: tick_interval,
        logger: logger,
        time: time, process: process, kernel: kernel)

      update_status_thread = create_update_status_thread(
        id: id,
        interval: status_interval,
        tick_interval: tick_interval,
        logger: logger,
        time: time, process: process, kernel: kernel)

      loop do
        case @status
        when Status::PUBLISHING
          dequeue_messages(
            id: id, queue: queue, batch_size: batch_size,
            poll_interval: poll_interval, tick_interval:, logger: logger,
            process: process, kernel: kernel)
        when Status::PAUSED
          Publisher.sleep(
            tick_interval,
            start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
            tick_interval: tick_interval,
            process: process, kernel: kernel)
        when Status::TERMINATING
          break
        end
      end

      logger.info "Outboxer terminating"

      concurrency.times { queue.push(nil) }
      publisher_threads.each(&:join)
      update_status_thread.join
      trap_signal_thread.join

      terminated(id: id, logger: logger)

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

      terminate(id: id, logger: logger)
    end
  end
end
