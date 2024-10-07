module Outboxer
  module Publisher
    extend self

    @status = nil
    @trapped_signal = nil

    Status = Models::Publisher::Status

    Signal.trap("TERM") { @trapped_signal = :term }
    Signal.trap("INT")  { @trapped_signal = :int }
    Signal.trap("TSTP") { @trapped_signal = :tstp }
    Signal.trap("CONT") { @trapped_signal = :cont }
    Signal.trap("TTIN") { @trapped_signal = :ttin }

    def start(name:, current_time:)
      original_status = @status

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.create!(
            name: name, status: Status::PUBLISHING, info: {},
            created_at: current_time, updated_at: current_time)

          publisher.id
        end
      end
    rescue StandardError => exception
      @status = original_status

      logger.error "Outboxer publisher status failed to transition "\
        "from #{original_status} to #{Status::PUBLISHING}"

      logger.error "#{exception.class}: #{exception.message}"
      exception.backtrace.each { |frame| logger.error frame }

      raise
    end

    # TODO: pass current_time
    def pause(id:, logger:)
      original_status = @status

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock('FOR UPDATE NOWAIT').find_by!(id: id)

          if publisher.status != Status::PUBLISHING
            raise ArgumentError, "status must be #{Status::PUBLISHING}"
          end

          publisher.update!(status: Status::PAUSING)

          @status = publisher.status
        end
      end
    rescue StandardError => exception
      @status = original_status

      logger.error "Outboxer publisher status failed to transition "\
        "from #{original_status} to #{Status::PAUSING}"

      logger.error "#{exception.class}: #{exception.message}"
      exception.backtrace.each { |frame| logger.error frame }
    end

    def paused(id:, logger:)
      original_status = @status

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock('FOR UPDATE NOWAIT').find_by!(id: id)

          if publisher.status != Status::PAUSING
            raise ArgumentError, "status must be #{Status::PAUSING}"
          end

          publisher.update!(status: Status::PAUSED)

          @status = publisher.status
        end
      end
    rescue StandardError => exception
      @status = original_status

      logger.error "Outboxer publisher status failed to transition "\
        "from #{original_status} to #{Status::PAUSED}"

      logger.error "#{exception.class}: #{exception.message}"
      exception.backtrace.each { |frame| logger.error frame }
    end

    def resume(id:, logger:)
      original_status = @status

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock('FOR UPDATE NOWAIT').find_by!(id: id)

          if publisher.status != Status::PAUSED
            raise ArgumentError, "status must be #{Status::PAUSED}"
          end

          publisher.update!(status: Status::RESUMING)

          @status = publisher.status
        end
      end
    rescue StandardError => exception
      @status = original_status

      logger.error "Outboxer publisher status failed to transition "\
        "from #{original_status} to #{Status::RESUMING}"

      logger.error "#{exception.class}: #{exception.message}"
      exception.backtrace.each { |frame| logger.error frame }
    end

    def resumed(id:, logger:)
      original_status = @status

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock('FOR UPDATE NOWAIT').find_by!(id: id)

          if publisher.status != Status::RESUMING
            raise ArgumentError, "status must be #{Status::RESUMING}"
          end

          publisher.update!(status: Status::PUBLISHING)

          @status = publisher.status
        end
      end
    rescue StandardError => exception
      @status = original_status

      logger.error "Outboxer publisher status failed to transition "\
        "from #{original_status} to #{Status::PUBLISHING}"

      logger.error "#{exception.class}: #{exception.message}"
      exception.backtrace.each { |frame| logger.error frame }
    end

    def terminate(id:, logger:)
      original_status = @status

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock('FOR UPDATE NOWAIT').find_by!(id: id)
          publisher.update!(status: Status::TERMINATING)

          @status = publisher.status
        end
      end
    rescue StandardError => exception
      @status = original_status

      logger.error "Outboxer publisher status failed to transition "\
        "from #{original_status} to #{Status::TERMINATING}"

      logger.error "#{exception.class}: #{exception.message}"
      exception.backtrace.each { |frame| logger.error frame }
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
    rescue StandardError => exception
      @status = original_status

      logger.error "Outboxer publisher status failed to transition "\
        "from #{original_status} to (deleted)"

      logger.error "#{exception.class}: #{exception.message}"
      exception.backtrace.each { |frame| logger.error frame }
    end

    # :nocov:
    def sleep(duration, start_time:, tick_interval:, process:, kernel:) # TODO: include PAUSING and RESUMING in quick exit
      while (@status != Status::TERMINATING) &&
          (process.clock_gettime(process::CLOCK_MONOTONIC) - start_time) < duration
        kernel.sleep(tick_interval)
      end
    end
    # :nocov:

    def create_signal_thread(id:, signal_interval:, tick_interval:, logger:,
                             process:, kernel:)
      Thread.new do
        while @status != Status::TERMINATING
          if !@trapped_signal.nil?
            case @trapped_signal
            when :term
              terminate(id: id, logger: logger)
            when :int
              terminate(id: id, logger: logger)
            when :tstp
              pause(id: id, logger: logger)
            when :cont
              resume(id: id, logger: logger)
            when :ttin
              Thread.list.each_with_index do |thread, index|
                logger.info thread.backtrace.join("\n") if thread.backtrace
              end
            end

            @trapped_signal = nil
          end

          Publisher.sleep(
            signal_interval,
            start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
            tick_interval: tick_interval,
            process: process, kernel: kernel)
        end
      end
    end

    def create_monitor_thread(id:, monitor_interval:, tick_interval:, logger:,
                              time:, process:, kernel:)
      Thread.new do
        while @status != Status::TERMINATING
          ActiveRecord::Base.connection_pool.with_connection do
            ActiveRecord::Base.transaction do
              throughput = messages = Models::Message
                .where(updated_by: name)
                .where('updated_at >= ?', 1.second.ago)
                .count

              start_rtt = process.clock_gettime(process::CLOCK_MONOTONIC)
              publisher = Models::Publisher.lock('FOR UPDATE NOWAIT').find_by!(id: id)
              end_rtt = process.clock_gettime(process::CLOCK_MONOTONIC)
              rtt = end_rtt - start_rtt

              publisher.update!(
                updated_at: time.now,
                info: {
                  throughput: throughput,
                  cpu_usage: `ps -p #{process.pid} -o %cpu`.split("\n").last.to_f,
                  rss: `ps -p #{process.pid} -o rss`.split("\n").last.to_i,
                  rtt: rtt })
            end
          end

          Publisher.sleep(
            monitor_interval,
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

    def publish(
      batch_size: 100, concurrency: 1,
      poll_interval: 5, tick_interval: 0.1, signal_interval: 1, monitor_interval: 10,
      logger: Logger.new($stdout, level: Logger::INFO),
      time: ::Time, socket: ::Socket, process: ::Process, kernel: ::Kernel,
      &block
    )
      logger.info "Outboxer v#{Outboxer::VERSION} publishing in ruby #{RUBY_VERSION} "\
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      logger.info "Outboxer config {"\
        " batch_size: #{batch_size}, concurrency: #{concurrency},"\
        " poll_interval: #{poll_interval}, tick_interval: #{tick_interval},"\
        " signal_interval: #{signal_interval}, monitor_interval: #{monitor_interval} }"

      id = start(name: "#{socket.gethostname}:#{process.pid}", current_time: time.now)

      queue = Queue.new

      publisher_threads = create_publisher_threads(
        queue: queue,
        concurrency: concurrency,
        logger: logger,
        time: time,
        kernel: kernel)

      # monitor_thread = create_monitor_thread(
      #   id: id,
      #   monitor_interval: monitor_interval,
      #   tick_interval: tick_interval,
      #   logger: logger,
      #   time: time, process: process, kernel: kernel)

      signal_thread = create_signal_thread(
        id: id,
        signal_interval: signal_interval,
        tick_interval: tick_interval,
        logger: logger,
        process: process, kernel: kernel)

      while @status != Status::TERMINATING
        case @status
        when Status::PUBLISHING
          dequeue_messages(
            id: id, queue: queue, batch_size: batch_size,
            poll_interval: poll_interval, tick_interval:, logger: logger,
            process: process, kernel: kernel)
        when Status::PAUSING
          paused(id: id, logger: logger)
        when Status::PAUSED
          Publisher.sleep(
            tick_interval,
            start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
            tick_interval: tick_interval,
            process: process, kernel: kernel)
        when Status::RESUMING
          resumed(id: id, logger: logger)
        end
      end

      logger.info "Outboxer terminating"

      concurrency.times { queue.push(nil) }
      publisher_threads.each(&:join)
      # monitor_thread.join
      signal_thread.join

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
