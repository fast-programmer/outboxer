module Outboxer
  module Publisher
    extend self

    class Error < StandardError; end

    class NotFound < Error
      def initialize(id:)
        super("Couldn't find Outboxer::Models::Publisher with 'id'=#{id}")
      end
    end

    def find_by_id(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.includes(:signals).find_by!(id: id)

          {
            id: publisher.id,
            name: publisher.name,
            status: publisher.status,
            settings: publisher.settings,
            metrics: publisher.metrics,
            created_at: publisher.created_at.utc,
            updated_at: publisher.updated_at.utc,
            signals: publisher.signals.map do |signal|
              {
                id: signal.id,
                name: signal.name,
                created_at: signal.created_at.utc,
              }
            end
          }
        end
      end
    rescue ActiveRecord::RecordNotFound => error
      raise NotFound.new(id: id), cause: error
    end

    def create(name:, buffer:, concurrency:,
               tick:, poll:, heartbeat:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.create!(
            name: name,
            status: Status::PUBLISHING,
            settings: {
              'buffer' => buffer,
              'concurrency' => concurrency,
              'tick' => tick,
              'poll' => poll,
              'heartbeat' => heartbeat },
            metrics: {
              'throughput' => 0,
              'latency' => 0,
              'cpu' => 0,
              'rss ' => 0,
              'rtt' => 0 },
            created_at: current_time,
            updated_at: current_time)

          @status = Status::PUBLISHING

          {
            id: publisher.id,
            name: publisher.name,
            status: publisher.status,
            settings: publisher.settings,
            metrics: publisher.metrics,
            created_at: publisher.created_at,
            updated_at: publisher.updated_at
          }
        end
      end
    end

    def delete(id:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          begin
            publisher = Models::Publisher.lock.find_by!(id: id)
            publisher.signals.destroy_all
            publisher.destroy!
          rescue ActiveRecord::RecordNotFound
            # no op
          end
        end
      end
    end

    Status = Models::Publisher::Status

    def stop(id:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          begin
            publisher = Models::Publisher.lock.find(id)
          rescue ActiveRecord::RecordNotFound => error
            raise NotFound.new(id: id), cause: error
          end

          publisher.update!(status: Status::STOPPED, updated_at: current_time)

          @status = Status::STOPPED
        end
      end
    end

    def continue(id:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          begin
            publisher = Models::Publisher.lock.find(id)
          rescue ActiveRecord::RecordNotFound => error
            raise NotFound.new(id: id), cause: error
          end

          publisher.update!(status: Status::PUBLISHING, updated_at: current_time)

          @status = Status::PUBLISHING
        end
      end
    end

    def terminate(id:, current_time: Time.now)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          begin
            publisher = Models::Publisher.lock.find(id)
            publisher.update!(status: Status::TERMINATING, updated_at: current_time)

            @status = Status::TERMINATING
          rescue ActiveRecord::RecordNotFound
            @status = Status::TERMINATING
          end
        end
      end
    end

    def signal(id:, name:, current_utc_time: Time.now.utc)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          begin
            publisher = Models::Publisher.lock.find(id)
          rescue ActiveRecord::RecordNotFound => error
            raise NotFound.new(id: id), cause: error
          end

          publisher.signals.create!(name: name, created_at: current_utc_time)

          nil
        end
      end
    end

    # :nocov:
    def sleep(duration, start_time:, tick:, signal_read:, process:, kernel:)
      while (
        (@status != Status::TERMINATING) &&
          ((process.clock_gettime(process::CLOCK_MONOTONIC) - start_time) < duration) &&
          !IO.select([signal_read], nil, nil, 0))
        kernel.sleep(tick)
      end
    end
    # :nocov:

    def trap_signals(id:)
      signal_read, signal_write = IO.pipe

      %w[TTIN TSTP CONT INT TERM].each do |signal_name|
        old_handler = Signal.trap(signal_name) do
          if old_handler.respond_to?(:call)
            old_handler.call
          end

          signal_write.puts(signal_name)
        end
      end

      [signal_read, signal_write]
    end

    def create_publisher_threads(id:, name:,
                                 queue:, concurrency:,
                                 logger:, process:, kernel:, &block)
      concurrency.times.each_with_index.map do |_, index|
        Thread.new do
          Thread.current.name = "publisher-#{index + 1}"

          while (message = queue.pop)
            break if message.nil?

            publish_message(
              id: id, name: name, buffered_message: message,
              logger: logger, process: process, kernel: kernel, &block)
          end
        end
      end
    end

    def buffer_messages(id:, name:,
                        queue:, buffer:, poll:, tick:,
                        signal_read:, logger:, process:, kernel:)
      buffer_limit = buffer - queue.size

      if buffer_limit > 0
        buffered_messages = Messages.buffer(
          limit: buffer_limit, publisher_id: id, publisher_name: name)

        if buffered_messages.count > 0
          buffered_messages.each { |message| queue.push(message) }
        else
          Publisher.sleep(
            poll,
            start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
            tick: tick,
            signal_read: signal_read,
            process: process, kernel: kernel)
        end
      else
        Publisher.sleep(
          tick,
          start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
          tick: tick,
          signal_read: signal_read,
          process: process, kernel: kernel)
      end
    rescue StandardError => e
      logger.error(
        "#{e.class}: #{e.message}\n"\
        "#{e.backtrace.join("\n")}")
    rescue Exception => e
      logger.fatal(
        "#{e.class}: #{e.message}\n"\
        "#{e.backtrace.join("\n")}")

      terminate(id: id)
    end

    def create_heartbeat_thread(id:, name:,
                                heartbeat:, tick:, signal_read:,
                                logger:, time:, socket:, process:, kernel:)
      Thread.new do
        Thread.current.name = "heartbeat"

        while @status != Status::TERMINATING
          begin
            current_time = time.now

            cpu = `ps -p #{process.pid} -o %cpu`.split("\n").last.to_f
            rss = `ps -p #{process.pid} -o rss`.split("\n").last.to_i

            ActiveRecord::Base.connection_pool.with_connection do
              ActiveRecord::Base.transaction do
                start_rtt = process.clock_gettime(process::CLOCK_MONOTONIC)

                begin
                  publisher = Models::Publisher.lock.find(id)
                rescue ActiveRecord::RecordNotFound => error
                  raise NotFound.new(id: id), cause: error
                end

                end_rtt = process.clock_gettime(process::CLOCK_MONOTONIC)
                rtt = end_rtt - start_rtt

                signal = publisher.signals.order(created_at: :asc).first

                if !signal.nil?
                  handle_signal(id: id, name: signal.name, logger: logger, process: process)
                  signal.destroy
                end

                throughput = Models::Message
                  .where(status: Models::Message::Status::PUBLISHED)
                  .where(updated_by_publisher_id: id)
                  .where('updated_at >= ?', 1.second.ago)
                  .count

                last_updated_message = Models::Message
                  .where(updated_by_publisher_id: id)
                  .order(updated_at: :desc)
                  .first

                publisher.update!(
                  updated_at: current_time,
                  metrics: {
                    throughput: throughput,
                    latency: last_updated_message.nil? ? 0 : (time.now - last_updated_message.updated_at).to_i,
                    cpu: cpu,
                    rss: rss,
                    rtt: rtt } )
              end
            end

            Publisher.sleep(
              heartbeat,
              signal_read: signal_read,
              start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
              tick: tick,
              process: process, kernel: kernel)

          rescue NotFound => e
            logger.fatal(
              "#{e.class}: #{e.message}\n"\
              "#{e.backtrace.join("\n")}")

            terminate(id: id)
          rescue StandardError => e
            logger.error(
              "#{e.class}: #{e.message}\n"\
              "#{e.backtrace.join("\n")}")

            Publisher.sleep(
              heartbeat,
              signal_read: signal_read,
              start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
              tick: tick,
              process: process, kernel: kernel)
          rescue Exception => e
            logger.fatal(
              "#{e.class}: #{e.message}\n"\
              "#{e.backtrace.join("\n")}")

            terminate(id: id)
          end
        end
      end
    end

    def handle_signal(id:, name:, logger:, process:)
      case name
      when 'TTIN'
        Thread.list.each_with_index do |thread, index|
          logger.info(
            "Outboxer dumping thread #{thread.name || thread.object_id}\n"\
            "#{thread.backtrace.present? ? thread.backtrace.join("\n") : '<no backtrace available>'}")
        end
      when 'TSTP'
        logger.info("Outboxer pausing threads")

        begin
          stop(id: id)
        rescue NotFound => e
          logger.fatal(
            "#{e.class}: #{e.message}\n"\
            "#{e.backtrace.join("\n")}")

          terminate(id: id)
        end
      when 'CONT'
        logger.info("Outboxer resuming threads")

        begin
          continue(id: id)
        rescue NotFound => e
          logger.fatal(
            "#{e.class}: #{e.message}\n"\
            "#{e.backtrace.join("\n")}")

          terminate(id: id)
        end
      when 'INT', 'TERM'
        logger.info("Outboxer terminating threads")

        terminate(id: id)
      end
    end

    def publish(
      name: "#{::Socket.gethostname}:#{::Process.pid}",
      env: 'development',
      db_config_path: ::File.expand_path('config/database.yml', ::Dir.pwd),
      buffer: 1000, concurrency: 2,
      tick: 0.1, poll: 5.0, heartbeat: 5.0,
      logger: Logger.new($stdout, level: Logger::INFO),
      database: Database,
      time: ::Time, socket: ::Socket, process: ::Process, kernel: ::Kernel,
      &block
    )
      Thread.current.name = "main"

      logger.info "Outboxer v#{Outboxer::VERSION} running in ruby #{RUBY_VERSION} "\
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      db_config = database.config(env: env, pool: concurrency + 2, path: db_config_path)
      database.connect(config: db_config, logger: logger)

      queue = Queue.new

      publisher = create(
        name: name, buffer: buffer, concurrency: concurrency,
        tick: tick, poll: poll, heartbeat: heartbeat)
      id = publisher[:id]

      publisher_threads = create_publisher_threads(
        id: id, name: name, queue: queue, concurrency: concurrency,
        logger: logger, process: process, kernel: kernel,
        &block)

      signal_read, _signal_write = trap_signals(id: publisher[:id])

      heartbeat_thread = create_heartbeat_thread(
        id: id, name: name,
        heartbeat: heartbeat,
        tick: tick,
        signal_read: signal_read,
        logger: logger,
        time: time, socket: socket, process: process, kernel: kernel)

      loop do
        case @status
        when Status::PUBLISHING
          buffer_messages(
            id: id, name: name,
            queue: queue, buffer: buffer,
            poll: poll, tick:,
            signal_read: signal_read, logger: logger, process: process, kernel: kernel)
        when Status::STOPPED
          Publisher.sleep(
            tick,
            start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
            tick: tick,
            signal_read: signal_read, process: process, kernel: kernel)
        when Status::TERMINATING
          break
        end

        if IO.select([signal_read], nil, nil, 0)
          signal_name = signal_read.gets.strip rescue nil

          handle_signal(id: id, name: signal_name, logger: logger, process: process)
        end
      end

      logger.info "Outboxer terminating"

      concurrency.times { queue.push(nil) }
      publisher_threads.each(&:join)
      heartbeat_thread.join

      delete(id: id)

      logger.info "Outboxer terminated"
    ensure
      database.disconnect(logger: logger)
    end

    def publish_message(id:, name:, buffered_message:, logger:, kernel:, process:, &block)
      buffered_at = process.clock_gettime(Process::CLOCK_MONOTONIC)

      message = Message.publishing(
        id: buffered_message[:id], publisher_id: id, publisher_name: name)
      logger.debug "Outboxer publishing message #{message[:id]} for "\
        "#{message[:messageable_type]}::#{message[:messageable_id]} "\
        "in #{(process.clock_gettime(Process::CLOCK_MONOTONIC) - buffered_at).round(3)}s"

      begin
        block.call(message)
      rescue Exception => e
        Message.failed(id: message[:id], exception: e, publisher_id: id, publisher_name: name)
        logger.debug "Outboxer failed to publish message #{message[:id]} for "\
          "#{message[:messageable_type]}::#{message[:messageable_id]} "\
          "in #{(process.clock_gettime(Process::CLOCK_MONOTONIC) - buffered_at).round(3)}s"

        raise
      end

      Message.published(id: message[:id], publisher_id: id, publisher_name: name)
      logger.debug "Outboxer published message #{message[:id]} for "\
        "#{message[:messageable_type]}::#{message[:messageable_id]} "\
        "in #{(process.clock_gettime(Process::CLOCK_MONOTONIC) - buffered_at).round(3)}s"
    rescue StandardError => e
      logger.error(
        "#{e.class}: #{e.message}\n"\
        "#{e.backtrace.join("\n")}")
    rescue Exception => e
      logger.fatal(
        "#{e.class}: #{e.message}\n"\
        "#{e.backtrace.join("\n")}")

      terminate(id: id)
    end
  end
end
