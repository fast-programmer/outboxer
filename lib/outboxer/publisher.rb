module Outboxer
  module Publisher
    extend self

    def create(identifier:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.create!(
            identifier: identifier, status: Status::PUBLISHING, info: {},
            created_at: current_time, updated_at: current_time)

          {
            id: publisher.id,
            identifier: publisher.identifier,
            status: publisher.status,
            created_at: publisher.created_at,
            updated_at: publisher.updated_at
          }
        end
      end
    end

    def delete(identifier:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.where(identifier: identifier).lock.first!
          publisher.destroy!
        end
      end
    end

    Status = Models::Publisher::Status

    # :nocov:
    def sleep(duration, start_time:, tick_interval:, signal_read:, signal_write:, process:, kernel:)
      while (@status != Status::TERMINATING) &&
          (process.clock_gettime(process::CLOCK_MONOTONIC) - start_time) < duration
        if IO.select([signal_read], nil, nil, 0)
          signal_name = signal_read.gets.strip rescue nil

          case signal_name
          when 'INT', 'TERM'
            @status = Status::TERMINATING
          else
            signal_write.puts(signal_name)
          end
        end

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

    def dequeue_messages(queue:, batch_size:,
                         poll_interval:, tick_interval:,
                         signal_read:, signal_write:,
                         logger:, process:, kernel:)
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
            signal_write: signal_write,
            process: process, kernel: kernel)
        end
      else
        Publisher.sleep(
          tick_interval,
          start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
          tick_interval: tick_interval,
          signal_read: signal_read,
          signal_write: signal_write,
          process: process, kernel: kernel)
      end
    rescue StandardError => exception
      logger.error "#{exception.class}: #{exception.message}"
      exception.backtrace.each { |frame| logger.error frame }
    rescue Exception => exception
      logger.fatal "#{exception.class}: #{exception.message}"
      exception.backtrace.each { |frame| logger.fatal frame }

      @status = Status::TERMINATING
    end

    def publish(
      batch_size: 100, concurrency: 1,
      poll_interval: 5, tick_interval: 0.1,
      logger: Logger.new($stdout, level: Logger::INFO),
      time: ::Time, socket: ::Socket, process: ::Process, kernel: ::Kernel,
      &block
    )
      logger.info "Outboxer v#{Outboxer::VERSION} publishing in ruby #{RUBY_VERSION} "\
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      queue = Queue.new
      @status = Status::PUBLISHING

      identifier = "#{::Socket.gethostname}:#{::Process.pid}:#{::SecureRandom.hex(6)}"

      publisher = create(identifier: identifier)

      logger.info "Outboxer config {"\
        " batch_size: #{batch_size}, concurrency: #{concurrency},"\
        " poll_interval: #{poll_interval}, tick_interval: #{tick_interval} }"\

      publisher_threads = create_publisher_threads(
        queue: queue,
        concurrency: concurrency,
        logger: logger,
        time: time,
        kernel: kernel,
        &block)

     signal_read, signal_write = trap_signals(id: publisher[:id])

      loop do
        case @status
        when Status::PUBLISHING
          dequeue_messages(
            queue: queue, batch_size: batch_size,
            poll_interval: poll_interval, tick_interval:,
            signal_read: signal_read, signal_write: signal_write,
            logger: logger, process: process, kernel: kernel)
        when Status::STOPPED
          Publisher.sleep(
            tick_interval,
            start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
            tick_interval: tick_interval,
            signal_read: signal_read, signal_write: signal_write,
            process: process, kernel: kernel)
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
            @status = Status::STOPPED
          when 'CONT'
            @status = Status::PUBLISHING
          when 'INT', 'TERM'
            @status = Status::TERMINATING
          end
        end
      end

      logger.info "Outboxer terminating"

      concurrency.times { queue.push(nil) }
      publisher_threads.each(&:join)

      delete(identifier: identifier)

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
