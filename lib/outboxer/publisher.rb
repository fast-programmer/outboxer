require "optparse"

module Outboxer
  # Manages the publishing of messages.
  module Publisher
    module_function

    def terminating?
      @status == Status::TERMINATING
    end

    # Parses command line arguments to configure the publisher.
    # @param args [Array<String>] The arguments passed via the command line.
    # @return [Hash] The parsed options including configuration path, environment,
    # buffer size, batch_size, and intervals.
    def self.parse_cli_options(args)
      options = {}

      parser = ::OptionParser.new do |opts|
        opts.banner = "Usage: outboxer_publisher [options]"

        opts.on("-e", "--environment ENV", "Application environment") do |v|
          options[:environment] = v
        end

        opts.on("-b", "--buffer-size SIZE", Integer, "Buffer size") do |v|
          options[:buffer_size] = v
        end

        opts.on("-B", "--batch-size SIZE", Integer, "Batch size") do |v|
          options[:batch_size] = v
        end

        opts.on("--buffering-threads-count N", Integer, "Buffering threads count") do |v|
          options[:buffering_threads_count] = v
        end

        opts.on("--publishing-threads-count N", Integer, "Publishing threads count") do |v|
          options[:publishing_threads_count] = v
        end

        opts.on("-t", "--tick-interval SECS", Float, "Tick interval in seconds") do |v|
          options[:tick_interval] = v
        end

        opts.on("-p", "--poll-interval SECS", Float, "Poll interval in seconds") do |v|
          options[:poll_interval] = v
        end

        opts.on("-a", "--heartbeat-interval SECS", Float, "Heartbeat interval in seconds") do |v|
          options[:heartbeat_interval] = v
        end

        opts.on("-s", "--sweep-interval SECS", Float, "Sweep interval in seconds") do |v|
          options[:sweep_interval] = v
        end

        opts.on("-r", "--sweep-retention SECS", Float, "Sweep retention in seconds") do |v|
          options[:sweep_retention] = v
        end

        opts.on("-w", "--sweep-batch-size SIZE", Integer, "Sweep batch size") do |v|
          options[:sweep_batch_size] = v
        end

        opts.on("-l", "--log-level LEVEL", Integer, "Log level") do |v|
          options[:log_level] = v
        end

        opts.on("-C", "--config PATH", "Path to YAML config file") do |v|
          options[:config] = v
        end

        opts.on("-V", "--version", "Print version and exit") do
          puts "Outboxer version #{Outboxer::VERSION}"
          exit
        end

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          exit
        end
      end

      parser.parse!(args)

      options
    end

    CONFIG_DEFAULTS = {
      path: "config/outboxer.yml",
      enviroment: "development"
    }

    # Loads and processes the YAML configuration for the publisher.
    # @param environment [String] The application environment.
    # @param path [String] The path to the configuration file.
    # @return [Hash] The processed configuration data with environment-specific overrides.
    def config(
      environment: CONFIG_DEFAULTS[:environment],
      path: CONFIG_DEFAULTS[:path]
    )
      path_expanded = ::File.expand_path(path)
      text = File.read(path_expanded)
      erb = ERB.new(text, trim_mode: "-")
      erb.filename = path_expanded
      erb_result = erb.result

      yaml = YAML.safe_load(erb_result, permitted_classes: [Symbol], aliases: true)
      yaml.deep_symbolize_keys!
      yaml_override = yaml.fetch(environment&.to_sym, {}).slice(*PUBLISH_MESSAGES_DEFAULTS.keys)
      yaml.slice(*PUBLISH_MESSAGES_DEFAULTS.keys).merge(yaml_override)
    rescue Errno::ENOENT
      {}
    end

    # Retrieves publisher data by ID including associated signals.
    # @param id [Integer] The ID of the publisher to find.
    # @return [Hash] Detailed information about the publisher including its signals.
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
                created_at: signal.created_at.utc
              }
            end
          }
        end
      end
    end

    # Creates a new publisher with specified settings and metrics.
    # @param name [String] The name of the publisher.
    # @param buffer_size [Integer] The buffer size.
    # @param buffering_threads_count [Integer] The number of buffering threads.
    # @param publishing_threads_count [Integer] The number of publishing threads.
    # @param tick_interval [Float] The tick interval in seconds.
    # @param poll_interval [Float] The poll interval in seconds.
    # @param heartbeat_interval [Float] The heartbeat interval in seconds.
    # @param time [Time] The current time context for timestamping.
    # @return [Hash] Details of the created publisher.
    def create(name:, buffer_size:,
               buffering_threads_count:, publishing_threads_count:,
               tick_interval:, poll_interval:, heartbeat_interval:,
               sweep_interval:, sweep_retention:, sweep_batch_size:,
               time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          current_utc_time = time.now.utc

          publisher = Models::Publisher.create!(
            name: name,
            status: Status::PUBLISHING,
            settings: {
              "buffer_size" => buffer_size,
              "buffering_threads_count" => buffering_threads_count,
              "publishing_threads_count" => publishing_threads_count,
              "tick_interval" => tick_interval,
              "poll_interval" => poll_interval,
              "heartbeat_interval" => heartbeat_interval,
              "sweep_interval" => sweep_interval,
              "sweep_retention" => sweep_retention,
              "sweep_batch_size" => sweep_batch_size
            },
            metrics: {
              "throughput" => 0,
              "latency" => 0,
              "cpu" => 0,
              "rss " => 0,
              "rtt" => 0
            },
            created_at: current_utc_time,
            updated_at: current_utc_time)

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

    # Deletes a publisher by ID, including all associated signals.
    # @param id [Integer] The ID of the publisher to delete.
    def delete(id:)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock.find_by!(id: id)
          publisher.signals.destroy_all
          publisher.destroy!
        rescue ActiveRecord::RecordNotFound
          # no op
        end
      end
    end

    Status = Models::Publisher::Status

    # Stops the publishing operations for a specified publisher.
    # @param id [Integer] The ID of the publisher to stop.
    # @param time [Time] The current time context for timestamping.
    def stop(id:, time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock.find(id)
          publisher.update!(status: Status::STOPPED, updated_at: time.now.utc)

          @status = Status::STOPPED
        end
      end
    end

    # Resumes the publishing operations for a specified publisher.
    # @param id [Integer] The ID of the publisher to resume.
    # @param time [Time] The current time context for timestamping.
    def continue(id:, time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock.find(id)

          publisher.update!(status: Status::PUBLISHING, updated_at: time.now.utc)

          @status = Status::PUBLISHING
        end
      end
    end

    # Terminates the publishing operations for a specified publisher.
    # @param id [Integer] The ID of the publisher to terminate.
    # @param time [Time] The current time context for timestamping.
    def terminate(id:, time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock.find(id)
          publisher.update!(status: Status::TERMINATING, updated_at: time.now.utc)

          @status = Status::TERMINATING
        rescue ActiveRecord::RecordNotFound
          @status = Status::TERMINATING
        end
      end
    end

    def signal(id:, name:, time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock.find(id)
          publisher.signals.create!(name: name, created_at: time.now.utc)

          nil
        end
      end
    end

    # Sleeps for the specified duration or until terminating, in tick-sized intervals.
    # @param duration [Float] The maximum duration to sleep in seconds.
    # @param tick_interval [Float] Interval between termination checks.
    # @param process [Process] Module used for monotonic clock timing.
    # @param kernel [Kernel] Module used for sleep operations.
    def sleep(duration, tick_interval:, process:, kernel:)
      start_time = process.clock_gettime(process::CLOCK_MONOTONIC)

      while !terminating? &&
            (process.clock_gettime(process::CLOCK_MONOTONIC) - start_time) < duration
        kernel.sleep(tick_interval)
      end
    end

    def trap_signals
      signal_read, signal_write = IO.pipe

      %w[TTIN TSTP CONT INT TERM].each do |signal_name|
        old_handler = ::Signal.trap(signal_name) do
          old_handler.call if old_handler.respond_to?(:call)

          signal_write.puts(signal_name)
        end
      end

      [signal_read, signal_write]
    end

    # Creates and manages threads dedicated to publishing operations.
    # @param id [Integer] The ID of the publisher.
    # @param name [String] The name of the publisher.
    # @param queue [Queue] The queue to manage publishing messages.
    # @param concurrency [Integer] The number of concurrent threads.
    # @param logger [Logger] The logger to use for logging operations.
    # @return [Array<Thread>] An array of threads managing publishing.
    # @yieldparam message [Hash] A message being processed.
    def create_worker_threads(id:, name:,
                              queue:, concurrency:,
                              logger:, &block)
      concurrency.times.each_with_index.map do |_, index|
        Thread.new do
          Thread.current.name = "publisher-#{index + 1}"

          while (buffered_messages = queue.pop)
            break if buffered_messages.nil?

            publish_buffered_messages(
              id: id, name: name, buffered_messages: buffered_messages,
              logger: logger, &block)
          end
        end
      end
    end

    # Handles the buffering of messages based on the publisher's buffer capacity.
    # @param id [Integer] The ID of the publisher.
    # @param name [String] The name of the publisher.
    # @param queue [Queue] The queue of messages to be published.
    # @param buffer_size [Integer] The buffer size.
    # @param poll_interval [Float] The poll interval in seconds.
    # @param tick_interval [Float] The tick interval in seconds.
    # @param signal_read [IO] The IO object to read signals.
    # @param logger [Logger] The logger to use for logging operations.
    # @param process [Process] The process object to use for timing.
    # @param kernel [Kernel] The kernel module to use for sleep operations.
    def buffer_messages(id:, name:, queue:, buffer_size:,
                        poll_interval:, tick_interval:,
                        signal_read:, logger:, process:, kernel:)
      buffer_remaining = buffer_size - queue.size

      if buffer_remaining > 0
        buffered_messages = Message.buffer(
          limit: buffer_remaining,
          publisher_id: id, publisher_name: name)

        if buffered_messages.any?
          queue.push(buffered_messages)
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
    rescue StandardError => error
      logger.error(
        "#{error.class}: #{error.message}\n" \
        "#{error.backtrace.join("\n")}")
    rescue ::Exception => error
      logger.fatal(
        "#{error.class}: #{error.message}\n" \
        "#{error.backtrace.join("\n")}")

      terminate(id: id)
    end

    # Creates a new thread that manages heartbeat checks, providing system metrics and
    # handling the first signal in the queue.
    # @param id [Integer] The ID of the publisher.
    # @param heartbeat [Float] The interval in seconds between heartbeats.
    # @param tick [Float] The base interval in seconds for sleeping during the loop.
    # @param signal_read [IO] An IO object for reading signals.
    # @param logger [Logger] A logger for logging heartbeat and system status.
    # @param time [Time] Current time context.
    # @param process [Process] The process module for accessing system metrics.
    # @param kernel [Kernel] The kernel module for sleeping operations.
    # @return [Thread] The heartbeat thread.
    def create_heartbeat_thread(id:,
                                heartbeat_interval:, tick_interval:,
                                logger:, time:, process:, kernel:)
      Thread.new do
        Thread.current.name = "heartbeat"

        while @status != Status::TERMINATING
          begin
            cpu = `ps -p #{process.pid} -o %cpu`.split("\n").last.to_f
            rss = `ps -p #{process.pid} -o rss`.split("\n").last.to_i

            ActiveRecord::Base.connection_pool.with_connection do
              ActiveRecord::Base.transaction do
                start_rtt = process.clock_gettime(process::CLOCK_MONOTONIC)

                publisher = Models::Publisher.lock.find(id)

                end_rtt = process.clock_gettime(process::CLOCK_MONOTONIC)
                rtt = end_rtt - start_rtt

                signal = publisher.signals.order(created_at: :asc).first

                if !signal.nil?
                  handle_signal(id: id, name: signal.name, logger: logger)
                  signal.destroy
                end

                throughput = Models::Message
                  .where(status: Message::Status::PUBLISHED)
                  .where(publisher_id: id)
                  .where("published_at >= ?", 1.second.ago)
                  .count

                last_published_message = Models::Message
                  .where(status: Message::Status::PUBLISHED)
                  .where(publisher_id: id)
                  .order(published_at: :desc)
                  .first

                latency = if last_published_message.nil?
                            0
                          else
                            (Time.now.utc - last_published_message.published_at).to_i
                          end

                publisher.update!(
                  updated_at: time.now.utc,
                  metrics: {
                    throughput: throughput,
                    latency: latency,
                    cpu: cpu,
                    rss: rss,
                    rtt: rtt
                  })
              end
            end

            Publisher.sleep(
              heartbeat_interval,
              tick_interval: tick_interval,
              process: process, kernel: kernel)
          rescue ActiveRecord::RecordNotFound => error
            logger.fatal(
              "#{error.class}: #{error.message}\n" \
              "#{error.backtrace.join("\n")}")

            terminate(id: id)
          rescue StandardError => error
            logger.error(
              "#{error.class}: #{error.message}\n" \
              "#{error.backtrace.join("\n")}")

            Publisher.sleep(
              heartbeat_interval,
              tick_interval: tick_interval, process: process, kernel: kernel)
          rescue ::Exception => error
            logger.fatal(
              "#{error.class}: #{error.message}\n" \
              "#{error.backtrace.join("\n")}")

            terminate(id: id)
          end
        end
      end
    end

    # Handles received signals and takes appropriate actions
    # such as pausing, resuming, or terminating the publisher.
    # @param id [Integer] The ID of the publisher affected by the signal.
    # @param name [String] The name of the signal received.
    # @param logger [Logger] The logger to record actions taken in response to the signal.
    def handle_signal(id:, name:, logger:)
      case name
      when "TTIN"
        Thread.list.each do |thread|
          thread_name = thread.name || thread.object_id
          backtrace = thread.backtrace || ["<no backtrace available>"]
          logger.info(
            "Outboxer dumping thread #{thread_name}\n" +
              backtrace.join("\n"))
        end
      when "TSTP"
        logger.info("Outboxer pausing threads")

        begin
          stop(id: id)
        rescue ActiveRecord::RecordNotFound => error
          logger.fatal(
            "#{error.class}: #{error.message}\n" \
            "#{error.backtrace.join("\n")}")

          terminate(id: id)
        end
      when "CONT"
        logger.info("Outboxer resuming threads")

        begin
          continue(id: id)
        rescue ActiveRecord::RecordNotFound => error
          logger.fatal(
            "#{error.class}: #{error.message}\n" \
            "#{error.backtrace.join("\n")}")

          terminate(id: id)
        end
      when "INT", "TERM"
        logger.info("Outboxer terminating threads")

        terminate(id: id)
      end
    end

    PUBLISH_MESSAGES_DEFAULTS = {
      buffer_size: 100,
      batch_size: 1000,
      buffering_threads_count: 1,
      publishing_threads_count: 1,
      tick_interval: 0.1,
      poll_interval: 5.0,
      heartbeat_interval: 5.0,
      sweep_interval: 60,
      sweep_retention: 60,
      sweep_batch_size: 100,
      log_level: 1
    }

    # Publish queued messages concurrently
    # @param name [String] The name of the publisher.
    # @param buffer_size [Integer] The buffer size.
    # @param buffering_threads_count [Integer] The number of threads buffering queued messages.
    # @param publishing_threads_count [Integer] The number of threads publishing buffered messages.
    # @param tick_interval [Float] The tick interval in seconds.
    # @param poll_interval [Float] The poll interval in seconds.
    # @param heartbeat_interval [Float] The heartbeat interval in seconds.
    # @param sweep_interval [Float] The interval in seconds between sweeper runs.
    # @param sweep_retention [Float] The retention period in seconds for published messages.
    # @param sweep_batch_size [Integer] The maximum number of messages to delete per batch.
    # @param logger [Logger] Logger for recording publishing activities.
    # @param time [Time] The current time context.
    # @param process [Process] The process module for system metrics.
    # @param kernel [Kernel] The kernel module for sleeping operations.
    # @yield [publisher, messages] Yields publisher and messages to be published.
    # @yieldparam publisher [Hash] A hash with keys `:id` and `:name` representing the publisher.
    # @yieldparam messages [Array<Hash>] An array of message hashes retrieved from the buffer.
    def publish_messages(
      name: "#{::Socket.gethostname}:#{::Process.pid}",
      buffer_size: PUBLISH_MESSAGES_DEFAULTS[:buffer_size],
      batch_size: PUBLISH_MESSAGES_DEFAULTS[:batch_size],
      buffering_threads_count: PUBLISH_MESSAGES_DEFAULTS[:buffering_threads_count],
      publishing_threads_count: PUBLISH_MESSAGES_DEFAULTS[:publishing_threads_count],
      tick_interval: PUBLISH_MESSAGES_DEFAULTS[:tick_interval],
      poll_interval: PUBLISH_MESSAGES_DEFAULTS[:poll_interval],
      heartbeat_interval: PUBLISH_MESSAGES_DEFAULTS[:heartbeat_interval],
      sweep_interval: PUBLISH_MESSAGES_DEFAULTS[:sweep_interval],
      sweep_retention: PUBLISH_MESSAGES_DEFAULTS[:sweep_retention],
      sweep_batch_size: PUBLISH_MESSAGES_DEFAULTS[:sweep_batch_size],
      logger: Logger.new($stdout, level: PUBLISH_MESSAGES_DEFAULTS[:log_level]),
      time: ::Time, process: ::Process, kernel: ::Kernel,
      &block
    )
      logger.info "Outboxer v#{Outboxer::VERSION} running in ruby #{RUBY_VERSION} " \
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      logger.info "Outboxer config " \
        "buffer_size=#{buffer_size}, " \
        "batch_size=#{batch_size}, " \
        "buffering_threads_count=#{buffering_threads_count}, " \
        "publishing_threads_count=#{publishing_threads_count}, " \
        "tick_interval=#{tick_interval} " \
        "poll_interval=#{poll_interval}, " \
        "heartbeat_interval=#{heartbeat_interval}, " \
        "sweep_interval=#{sweep_interval}, " \
        "sweep_retention=#{sweep_retention}, " \
        "sweep_batch_size=#{sweep_batch_size}, " \
        "log_level=#{logger.level}"

      Setting.create_all

      queue = SizedQueue.new(buffer_size)

      publisher = create(
        name: name, buffer_size: buffer_size,
        buffering_threads_count: buffering_threads_count,
        publishing_threads_count: publishing_threads_count,
        tick_interval: tick_interval, poll_interval: poll_interval,
        heartbeat_interval: heartbeat_interval,
        sweep_interval: sweep_interval,
        sweep_retention: sweep_retention,
        sweep_batch_size: sweep_batch_size)

      buffering_threads = create_buffering_threads(
        id: publisher[:id], name: name,
        count: buffering_threads_count,
        queue: queue,
        batch_size: batch_size,
        poll_interval: poll_interval, tick_interval: tick_interval,
        logger: logger, process: process, kernel: kernel)

      publishing_threads = create_publishing_threads(
        id: publisher[:id], name: name, queue: queue, count: publishing_threads_count,
        logger: logger, &block)

      heartbeat_thread = create_heartbeat_thread(
        id: publisher[:id], heartbeat_interval: heartbeat_interval, tick_interval: tick_interval,
        logger: logger, time: time, process: process, kernel: kernel)

      sweeper_thread = create_sweeper_thread(
        id: publisher[:id],
        sweep_interval: sweep_interval,
        sweep_retention: sweep_retention,
        sweep_batch_size: sweep_batch_size,
        tick_interval: tick_interval,
        logger: logger,
        time: time,
        process: process,
        kernel: kernel)

      signal_read, _signal_write = trap_signals

      while !terminating?
        signal_name = read_signal(signal_read: signal_read, tick_interval: tick_interval)
        handle_signal(id: publisher[:id], name: signal_name, logger: logger)
      end

      logger.info "Outboxer terminating"

      publishing_threads_count.times { queue.push(nil) }
      logger.info "#{Thread.current.name} pushed #{publishing_threads_count} nils to queue"

      buffering_threads.each(&:join)
      publishing_threads.each(&:join)
      heartbeat_thread.join
      sweeper_thread.join

      delete(id: publisher[:id])

      logger.info "Outboxer terminated"
    end

    # @param signal_read [IO] The read-end of the signal pipe.
    # @param tick_interval [Float] Seconds to wait for signal readability.
    # @return [String, nil] The signal name read from the pipe, or nil if none or error occurs.
    def read_signal(signal_read:, tick_interval:)
      signal_read.wait_readable(tick_interval) ? signal_read.gets&.chomp : nil
    rescue StandardError
      nil
    end

    # @param id [Integer] The ID of the publisher.
    # @param name [String] The name of the publisher.
    # @param queue [Queue] A sized queue to hold buffered messages.
    # @param count [Integer] The number of buffering threads to start.
    # @param batch_size [Integer] The number of messages to buffer per batch.
    # @param logger [Logger] Logger instance for logging errors or diagnostics.
    # @return [Array<Thread>] An array of started buffering threads.
    def create_buffering_threads(id:, name:, count:, queue:, batch_size:,
                                 poll_interval:, tick_interval:, logger:,
                                 process:, kernel:)
      Array.new(count) do |index|
        Thread.new do
          Thread.current.name = "buffering-#{index + 1}"

          while !terminating?
            begin
              buffered_messages = Message.buffer(
                publisher_id: id, publisher_name: name, limit: batch_size)

              if buffered_messages.any?
                queue.push(buffered_messages)

                logger.info "#{Thread.current.name} pushed #{buffered_messages.count} buffered messages to queue"
              else
                Publisher.sleep(
                  poll_interval, tick_interval: tick_interval, process: process, kernel: kernel)
              end
            rescue StandardError => error
              logger.error("#{error.class}: #{error.message}\n#{error.backtrace.join("\n")}")
            rescue Exception => error
              logger.fatal("#{error.class}: #{error.message}\n#{error.backtrace.join("\n")}")

              terminate(id: id)
            end
          end

          logger.info "#{Thread.current.name} shutting down"
        end
      end
    end

    # Creates and manages threads dedicated to publishing operations.
    # @param id [Integer] The ID of the publisher.
    # @param name [String] The name of the publisher.
    # @param queue [Queue] The queue to manage publishing messages.
    # @param concurrency [Integer] The number of concurrent threads.
    # @param logger [Logger] The logger to use for logging operations.
    # @return [Array<Thread>] An array of threads managing publishing.
    # @yieldparam message [Hash] A message being processed.
    def create_publishing_threads(id:, name:, queue:, count:,
                                  logger:, &block)
      Array.new(count) do |index|
        Thread.new do
          Thread.current.name = "publishing-#{index + 1}"

          while (messages = queue.pop)

            logger.info "#{Thread.current.name} popped from queue and size is now #{queue.size}"

            begin
              message_ids = messages.map { |message| message[:id] }

              publishing_messages = Message.publishing_by_ids(
                ids: message_ids, publisher_id: id, publisher_name: name)

              block.call({ id: id, name: name }, publishing_messages)
            rescue StandardError => error
              logger.error(
                "#{error.class}: #{error.message}\n" \
                  "#{error.backtrace.join("\n")}")
            rescue ::Exception => error
              logger.fatal(
                "#{error.class}: #{error.message}\n" \
                  "#{error.backtrace.join("\n")}")

              terminate(id: id)
            end
          end

          logger.info "#{Thread.current.name} shutting down"
        end
      end
    end

    # Retrieves all publishers including signals.
    # @return [Array<Hash>] A list of all publishers and their details.
    def all
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publishers = Models::Publisher.includes(:signals).all

          publishers.map do |publisher|
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
                  created_at: signal.created_at.utc
                }
              end
            }
          end
        end
      end
    end

    # Creates a sweeper thread to periodically delete old published messages for a publisher.
    #
    # @param id [Integer] The ID of the publisher.
    # @param sweep_interval [Float] Time in seconds between each sweep run.
    # @param sweep_retention [Float] Retention period in seconds for keeping published messages.
    # @param sweep_batch_size [Integer] Max number of messages to delete in each sweep.
    # @param tick_interval [Float] Time in seconds between signal checks while sleeping.
    # @param logger [Logger] Logger instance to report errors and fatal issues.
    # @param time [Time] Module used for fetching current UTC time.
    # @param process [Process] Process module used for monotonic clock timings.
    # @param kernel [Kernel] Kernel module used for sleeping between sweeps.
    # @return [Thread] The thread executing the sweeping logic.
    def create_sweeper_thread(id:, sweep_interval:, sweep_retention:, sweep_batch_size:,
                              tick_interval:, logger:, time:, process:, kernel:)
      Thread.new do
        Thread.current.name = "sweeper"

        while @status != Status::TERMINATING
          begin
            deleted_count = Message.delete_batch(
              status: Message::Status::PUBLISHED,
              older_than: time.now.utc - sweep_retention,
              batch_size: sweep_batch_size)[:deleted_count]

            if deleted_count == 0
              Publisher.sleep(
                sweep_interval,
                tick_interval: tick_interval,
                process: process,
                kernel: kernel)
            end
          rescue StandardError => error
            logger.error(
              "#{error.class}: #{error.message}\n" \
              "#{error.backtrace.join("\n")}")
          rescue ::Exception => error
            logger.fatal(
              "#{error.class}: #{error.message}\n" \
              "#{error.backtrace.join("\n")}")

            terminate(id: id)
          end
        end
      end
    end
  end
end
