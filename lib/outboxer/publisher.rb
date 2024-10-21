module Outboxer
  module Publisher
    extend self

    def create(key:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.create!(
            key: key, status: Status::PUBLISHING, info: {
              'throughput' => 0,
              'latency' => 0,
              'cpu' => 0,
              'rss ' => 0,
              'rtt' => 0
            },
            created_at: current_time, updated_at: current_time)

          @status = Status::PUBLISHING

          {
            id: publisher.id,
            key: publisher.key,
            status: publisher.status,
            created_at: publisher.created_at,
            updated_at: publisher.updated_at
          }
        end
      end
    end

    def delete(key:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock.find_by!(key: key)
          publisher.destroy!
        end
      end
    end

    Status = Models::Publisher::Status

    def stop(key:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock.find_by!(key: key)
          publisher.update!(status: Status::STOPPED, updated_at: current_time)

          @status = Status::STOPPED
        end
      end
    end

    def continue(key:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock.find_by!(key: key)
          publisher.update!(status: Status::PUBLISHING, updated_at: current_time)

          @status = Status::PUBLISHING
        end
      end
    end

    def terminate(key:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock.find_by!(key: key)
          publisher.update!(status: Status::TERMINATING, updated_at: current_time)

          @status = Status::TERMINATING
        end
      end
    end

    # :nocov:
    def sleep(duration, start_time:, tick_interval:, signal_read:, process:, kernel:)
      while (
        (@status != Status::TERMINATING) &&
          ((process.clock_gettime(process::CLOCK_MONOTONIC) - start_time) < duration) &&
          !IO.select([signal_read], nil, nil, 0))
        kernel.sleep(tick_interval)
      end
    end
    # :nocov:

    def trap_signals(id:)
      signal_read, signal_write = IO.pipe

      signal_names = %w[TTIN TSTP CONT INT TERM]

      signal_names.each do |signal_name|
        old_handler = Signal.trap(signal_name) do
          if old_handler.respond_to?(:call)
            old_handler.call
          end

          signal_write.puts(signal_name)
        end
      end

      [signal_read, signal_write]
    end

    def create_publisher_threads(key:, queue:, concurrency:, logger:, time:, kernel:, &block)
      concurrency.times.map do
        Thread.new do
          while (message = queue.pop)
            break if message.nil?

            publish_message(
              key: key,
              dequeued_message: message,
              logger: logger, time: time, kernel: kernel, &block)
          end
        end
      end
    end

    def dequeue_messages(key:, queue:, batch_size:,
                         poll_interval:, tick_interval:,
                         signal_read:, logger:, process:, kernel:)
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
            signal_read: signal_read,
            process: process, kernel: kernel)
        end
      else
        Publisher.sleep(
          tick_interval,
          start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
          tick_interval: tick_interval,
          signal_read: signal_read,
          process: process, kernel: kernel)
      end
    rescue StandardError => exception
      logger.error "#{exception.class}: #{exception.message}"
      exception.backtrace.each { |frame| logger.error frame }
    rescue Exception => exception
      logger.fatal "#{exception.class}: #{exception.message}"
      exception.backtrace.each { |frame| logger.fatal frame }

      terminate(key: key)
    end

    def create_heartbeat_thread(key:, heartbeat_interval:, tick_interval:, signal_read:,
                               logger:, time:, socket:, process:, kernel:)
      Thread.new do
        while @status != Status::TERMINATING
          current_time = time.now

          cpu = `ps -p #{process.pid} -o %cpu`.split("\n").last.to_f
          rss = `ps -p #{process.pid} -o rss`.split("\n").last.to_i

          ActiveRecord::Base.connection_pool.with_connection do
            ActiveRecord::Base.transaction do
              start_rtt = process.clock_gettime(process::CLOCK_MONOTONIC)
              publisher = Models::Publisher.lock.find_by!(key: key)
              end_rtt = process.clock_gettime(process::CLOCK_MONOTONIC)
              rtt = end_rtt - start_rtt

              throughput = messages = Models::Message
                .where(updated_by: key)
                .where('updated_at >= ?', 1.second.ago)
                .count

              last_updated_message = Models::Message
                .where(updated_by: name)
                .order(updated_at: :desc)
                .first

              publisher.update!(
                updated_at: current_time,
                info: {
                  throughput: throughput,
                  latency: last_updated_message.nil? ? 0 : (time.now - last_updated_message.updated_at).to_i,
                  cpu: cpu,
                  rss: rss,
                  rtt: rtt })
            end
          end

          Publisher.sleep(
            heartbeat_interval,
            signal_read: signal_read,
            start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
            tick_interval: tick_interval,
            process: process, kernel: kernel)
        end
      end
    end

    def publish(
      batch_size: 100, concurrency: 1,
      poll_interval: 5, tick_interval: 0.1, heartbeat_interval: 5,
      logger: Logger.new($stdout, level: Logger::INFO),
      time: ::Time, socket: ::Socket, process: ::Process, kernel: ::Kernel,
      &block
    )
      logger.info "Outboxer v#{Outboxer::VERSION} publishing in ruby #{RUBY_VERSION} "\
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      queue = Queue.new

      key = "#{::Socket.gethostname}:#{::Process.pid}:#{::SecureRandom.hex(6)}"

      publisher = create(key: key)

      logger.info "Outboxer config {"\
        " batch_size: #{batch_size}, concurrency: #{concurrency},"\
        " poll_interval: #{poll_interval}, tick_interval: #{tick_interval} }"\

      publisher_threads = create_publisher_threads(
        key: key, queue: queue, concurrency: concurrency,
        logger: logger, time: time, kernel: kernel,
        &block)

      signal_read, _signal_write = trap_signals(id: publisher[:id])

      heartbeat_thread = create_heartbeat_thread(
        key: key,
        heartbeat_interval: heartbeat_interval,
        tick_interval: tick_interval,
        signal_read: signal_read,
        logger: logger,
        time: time, socket: socket, process: process, kernel: kernel)

      loop do
        case @status
        when Status::PUBLISHING
          dequeue_messages(
            key: key,
            queue: queue, batch_size: batch_size,
            poll_interval: poll_interval, tick_interval:,
            signal_read: signal_read, logger: logger, process: process, kernel: kernel)
        when Status::STOPPED
          Publisher.sleep(
            tick_interval,
            start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
            tick_interval: tick_interval,
            signal_read: signal_read, process: process, kernel: kernel)
        when Status::TERMINATING
          break
        end

        if IO.select([signal_read], nil, nil, 0)
          signal_name = signal_read.gets.strip rescue nil

          case signal_name
          when 'TTIN'
            Thread.list.each_with_index do |thread, index|
              logger.info thread.backtrace.join("\n") if thread.backtrace
            end
          when 'TSTP'
            stop(key: key)
          when 'CONT'
            continue(key: key)
          when 'INT', 'TERM'
            terminate(key: key)
          end
        end
      end

      logger.info "Outboxer terminating"

      concurrency.times { queue.push(nil) }
      publisher_threads.each(&:join)
      heartbeat_thread.join

      delete(key: key)

      logger.info "Outboxer terminated"
    end

    def publish_message(key:, dequeued_message:, logger:, time:, kernel:, &block)
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

      terminate(key: key)
    end
  end
end
