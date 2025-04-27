require "optparse"

module Outboxer
  # Manages the publishing of messages.
  module Publisher
    module_function

    # Parses command line arguments to configure the publisher.
    # @param args [Array<String>] The arguments passed via the command line.
    # @return [Hash] The parsed options including configuration path, environment,
    # buffer size, concurrency, and intervals.
    def self.parse_cli_options(args)
      options = {}

      parser = ::OptionParser.new do |opts|
        opts.banner = "Usage: outboxer_publisher [options]"

        opts.on("-C", "--config PATH", "Path to YAML config file") do |v|
          options[:config] = v
        end

        opts.on("-e", "--environment ENV", "Application environment") do |v|
          options[:environment] = v
        end

        opts.on("-b", "--buffer-size SIZE", Integer, "Buffer size") do |v|
          options[:buffer_size] = v
        end

        opts.on("-c", "--concurrency SIZE", Integer, "Concurrency") do |v|
          options[:concurrency] = v
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

        opts.on("-l", "--log-level LEVEL", Integer, "Log level") do |v|
          options[:log_level] = v
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
      yaml_override = yaml.fetch(environment&.to_sym, {}).slice(*PUBLISH_DEFAULTS.keys)
      yaml.slice(*PUBLISH_DEFAULTS.keys).merge(yaml_override)
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
    # @param concurrency [Integer] The number of concurrent operations.
    # @param tick_interval [Float] The tick interval in seconds.
    # @param poll_interval [Float] The poll interval in seconds.
    # @param heartbeat_interval [Float] The heartbeat interval in seconds.
    # @param time [Time] The current time context for timestamping.
    # @return [Hash] Details of the created publisher.
    def create(name:, buffer_size:, concurrency:,
               tick_interval:, poll_interval:, heartbeat_interval:, time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          current_utc_time = time.now.utc

          publisher = Models::Publisher.create!(
            name: name,
            status: Status::PUBLISHING,
            settings: {
              "buffer_size" => buffer_size,
              "concurrency" => concurrency,
              "tick_interval" => tick_interval,
              "poll_interval" => poll_interval,
              "heartbeat_interval" => heartbeat_interval
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

    # Sleeps for the specified duration or until a signal is received, whichever comes first.
    # @param duration [Float] The maximum duration to sleep in seconds.
    # @param start_time [Time] The start time from which the duration is calculated.
    # @param tick [Float] The interval in seconds to check for signals.
    # @param signal_read [IO] An IO object to check for readable data.
    # @param process [Process] The process module used for timing.
    # @param kernel [Kernel] The kernel module used for sleeping.
    def sleep(duration, start_time:, tick_interval:, signal_read:, process:, kernel:)
      while (@status != Status::TERMINATING) &&
            ((process.clock_gettime(process::CLOCK_MONOTONIC) - start_time) < duration) &&
            !signal_read.wait_readable(0)
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
    def create_publisher_threads(id:, name:,
                                 queue:, concurrency:,
                                 logger:, &block)
      concurrency.times.each_with_index.map do |_, index|
        Thread.new do
          Thread.current.name = "publisher-#{index + 1}"

          while (buffered_message = queue.pop)
            break if buffered_message.nil?

            publish_buffered_message(
              id: id, name: name, buffered_message: buffered_message,
              logger: logger, &block)
          end
        end
      end
    end

    # Handles the buffering of messages based on the publisher's buffer capacity.
    # @param id [Integer] The ID of the publisher.
    # @param name [String] The name of the publisher.
    # @param queue [Queue] The queue of messages to be published.
    # @param buffer_size [Integer] The buffer sie.
    # @param poll_interval [Float] The poll interval in seconds.
    # @param tick_interval [Float] The tick interval in seconds.
    # @param signal_read [IO] The IO object to read signals.
    # @param logger [Logger] The logger to use for logging operations.
    # @param process [Process] The process object to use for timing.
    # @param kernel [Kernel] The kernel module to use for sleep operations.
    def buffer_messages(id:, name:, queue:, buffer_size:, poll_interval:, tick_interval:,
                        signal_read:, logger:, process:, kernel:)
      buffer_remaining = buffer_size - queue.size

      if buffer_remaining > 0
        buffered_messages = Message.buffer(
          limit: buffer_remaining, publisher_id: id, publisher_name: name)

        if buffered_messages.count > 0
          buffered_messages.each { |message| queue.push(message) }
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
                                heartbeat_interval:, tick_interval:, signal_read:,
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
                  .where("updated_at >= ?", 1.second.ago)
                  .count

                last_updated_message = Models::Message
                  .where(publisher_id: id)
                  .order(updated_at: :desc)
                  .first

                latency = if last_updated_message.nil?
                            0
                          else
                            (Time.now.utc - last_updated_message.updated_at).to_i
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
              signal_read: signal_read,
              start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
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
              signal_read: signal_read,
              start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
              tick_interval: tick_interval,
              process: process, kernel: kernel)
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

    PUBLISH_DEFAULTS = {
      buffer_size: 100,
      concurrency: 1,
      tick_interval: 0.1,
      poll_interval: 5.0,
      heartbeat_interval: 5.0,
      log_level: 1
    }

    # Publish queued messages concurrently
    # @param name [String] The name of the publisher.
    # @param buffer_size [Integer] The buffer size.
    # @param concurrency [Integer] The number of threads for concurrent publishing.
    # @param tick_interval [Float] The tick interval in seconds.
    # @param poll_interval [Float] The poll interval in seconds.
    # @param heartbeat_interval [Float] The heartbeat interval in seconds.
    # @param logger [Logger] Logger for recording publishing activities.
    # @param time [Time] The current time context.
    # @param process [Process] The process module for system metrics.
    # @param kernel [Kernel] The kernel module for sleeping operations.
    # @yield [Hash] A block to handle the publishing of each message.
    def publish_message(
      name: "#{::Socket.gethostname}:#{::Process.pid}",
      buffer_size: PUBLISH_DEFAULTS[:buffer_size],
      concurrency: PUBLISH_DEFAULTS[:concurrency],
      tick_interval: PUBLISH_DEFAULTS[:tick_interval],
      poll_interval: PUBLISH_DEFAULTS[:poll_interval],
      heartbeat_interval: PUBLISH_DEFAULTS[:heartbeat_interval],
      logger: Logger.new($stdout, level: PUBLISH_DEFAULTS[:log_level]),
      time: ::Time, process: ::Process, kernel: ::Kernel,
      &block
    )
      Thread.current.name = "main"

      logger.info "Outboxer v#{Outboxer::VERSION} running in ruby #{RUBY_VERSION} " \
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      logger.info "Outboxer config " \
        "buffer_size=#{buffer_size}, concurrency=#{concurrency}, " \
        "tick_interval=#{tick_interval}, poll_interval=#{poll_interval}, " \
        "heartbeat_interval=#{heartbeat_interval}, " \
        "log_level=#{logger.level}"

      Setting.create_all

      queue = Queue.new

      publisher = create(
        name: name, buffer_size: buffer_size, concurrency: concurrency,
        tick_interval: tick_interval, poll_interval: poll_interval,
        heartbeat_interval: heartbeat_interval)
      id = publisher[:id]

      publisher_threads = create_publisher_threads(
        id: id, name: name, queue: queue, concurrency: concurrency,
        logger: logger, &block)

      signal_read, _signal_write = trap_signals

      heartbeat_thread = create_heartbeat_thread(
        id: id,
        heartbeat_interval: heartbeat_interval,
        tick_interval: tick_interval,
        signal_read: signal_read,
        logger: logger,
        time: time, process: process, kernel: kernel)

      loop do
        case @status
        when Status::PUBLISHING
          buffer_messages(
            id: id, name: name,
            queue: queue, buffer_size: buffer_size,
            poll_interval: poll_interval, tick_interval: tick_interval,
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

        if signal_read.wait_readable(0)
          signal_name =
            begin
              signal_read.gets.strip
            rescue StandardError
              nil
            end

          handle_signal(id: id, name: signal_name, logger: logger)
        end
      end

      logger.info "Outboxer terminating"

      concurrency.times { queue.push(nil) }
      publisher_threads.each(&:join)
      heartbeat_thread.join

      delete(id: id)

      logger.info "Outboxer terminated"
    end

    # Publishes a buffered message
    # @param id [Integer] The ID of the publisher.
    # @param name [String] The name of the publisher.
    # @param buffered_message [Hash] The message data retrieved from the buffer.
    # @param logger [Logger] Logger for recording the outcome of the publishing attempt.
    # @yield [Hash] A block to process the publishing of the message.
    def publish_buffered_message(id:, name:, buffered_message:, logger:, &block)
      publishing_message = Message.publishing(
        id: buffered_message[:id], publisher_id: id, publisher_name: name)

      begin
        block.call(publishing_message)
      rescue ::Exception => error
        failed_message = Message.failed(
          id: publishing_message[:id], exception: error, publisher_id: id, publisher_name: name)

        logger.debug "Outboxer failed to publish message id=#{failed_message[:id]} " \
          "messageable=#{failed_message[:messageable_type]}::#{failed_message[:messageable_id]} " \
          "in #{(failed_message[:updated_at] - failed_message[:queued_at]).round(3)}s"

        raise
      end

      published_message = Message.published(
        id: publishing_message[:id], publisher_id: id, publisher_name: name)

      logger.debug "Outboxer published message id=#{published_message[:id]} " \
        "messageable=#{published_message[:messageable_type]}::" \
        "#{published_message[:messageable_id]} in " \
        "#{(published_message[:updated_at] - published_message[:queued_at]).round(3)}s"
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
  end
end
