module Outboxer
  module Publisher
    extend self

    def setup_signal_handlers(self_write)
      signal_names = %w[INT TERM TTIN TSTP]

      signal_names.each do |signal_name|
        old_handler = Signal.trap(signal_name) do
          if old_handler.respond_to?(:call)
            old_handler.call
          end

          self_write.puts(signal_name)
        end
      end
    end

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

          publisher.signals.each { |signal| signal.destroy! }
          publisher.destroy!
        end
      end
    end

    def create_signal(publisher_id:, name:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          signal = Models::Signal.create!(
            publisher_id: publisher_id, name: name,
            created_at: current_time, updated_at: current_time)

          { id: signal.id, name: signal.name, created_at: signal.created_at }
        end
      end
    end

    Status = Models::Publisher::Status

    def stop
      @status = Status::STOPPED
    end

    def resume
      @status = Status::PUBLISHING
    end

    def terminate
      @status = Status::TERMINATING
    end

    # :nocov:
    def sleep(duration, start_time:, tick_interval:, process:, kernel:)
      while (@status != Status::TERMINATING) &&
          (process.clock_gettime(process::CLOCK_MONOTONIC) - start_time) < duration
        kernel.sleep(tick_interval)
      end
    end
    # :nocov:

    def create_trap_signal_thread(publisher_id:)
      self_read, self_write = IO.pipe
      setup_signal_handlers(self_write)

      Thread.new do
        if self_read.wait_readable
          signal_name = self_read.gets.strip

          case signal_name
          when 'INT'
            terminate
          when 'TERM'
            terminate
          when 'TSTP'
            stop
          when 'CONT'
            resume
          when 'TTIN'
            Thread.list.each_with_index do |thread, index|
              logger.info thread.backtrace.join("\n") if thread.backtrace
            end
          else
            create_signal(publisher_id: publisher_id, name: signal_name)
          end
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

    def dequeue_messages(queue:, batch_size:,
                         poll_interval:, tick_interval:,
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

      trap_signal_thread = create_trap_signal_thread(publisher_id: publisher[:id])

      loop do
        case @status
        when Status::PUBLISHING
          dequeue_messages(
            queue: queue, batch_size: batch_size,
            poll_interval: poll_interval, tick_interval:,
            logger: logger, process: process, kernel: kernel)
        when Status::STOPPED
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
      trap_signal_thread.kill

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
