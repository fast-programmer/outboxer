require "optparse"

module Outboxer
  # Manages the publishing of messages.
  module Publisher
    module_function

    def terminating?
      @status == Status::TERMINATING
    end

    def publishing?
      @status == Status::PUBLISHING
    end

    # Parses command line arguments to configure the publisher.
    # @param args [Array<String>] The arguments passed via the command line.
    # @return [Hash] The parsed options.
    def self.parse_cli_options(args)
      options = {}

      parser = ::OptionParser.new do |opts|
        opts.banner = "Usage: outboxer_publisher [options]"

        opts.on("--environment ENV", "Application environment") do |v|
          options[:environment] = v
        end

        opts.on("--concurrency N", Integer, "Number of threads to publish messages") do |v|
          options[:concurrency] = v
        end

        opts.on("--tick-interval SECS", Float, "Tick interval in seconds") do |v|
          options[:tick_interval] = v
        end

        opts.on("--poll-interval SECS", Float, "Poll interval in seconds") do |v|
          options[:poll_interval] = v
        end

        opts.on("--heartbeat-interval SECS", Float, "Heartbeat interval in seconds") do |v|
          options[:heartbeat_interval] = v
        end

        opts.on("--log-level LEVEL", Integer, "Log level") do |v|
          options[:log_level] = v
        end

        opts.on("--version", "Print version and exit") do
          puts "Outboxer version #{Outboxer::VERSION}"
          exit
        end

        opts.on("--help", "Show this help message") do
          puts opts
          exit
        end
      end

      parser.parse!(args)

      options
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

    # Creates a new publisher with specified settings and metrics.
    # @param name [String] The name of the publisher.
    # @param concurrency [Integer] The number of publishing threads.
    # @param tick_interval [Float] The tick interval in seconds.
    # @param poll_interval [Float] The poll interval in seconds.
    # @param heartbeat_interval [Float] The heartbeat interval in seconds.
    # @param time [Time] The current time context for timestamping.
    # @return [Hash] Details of the created publisher.
    def create(name:, concurrency:,
               tick_interval:, poll_interval:, heartbeat_interval:,
               time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          current_utc_time = time.now.utc

          publisher = Models::Publisher.create!(
            name: name,
            status: Status::PUBLISHING,
            settings: {
              "concurrency" => concurrency,
              "tick_interval" => tick_interval,
              "poll_interval" => poll_interval,
              "heartbeat_interval" => heartbeat_interval
            },
            metrics: {
              "queued" => { "count" => 0, "throughput" => 0 },
              "publishing" => { "count" => 0, "throughput" => 0 },
              "published" => { "count" => 0, "throughput" => 0 },
              "failed" => { "count" => 0, "throughput" => 0 },
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

    # Creates a new thread that manages heartbeat checks, providing system metrics and
    # handling the first signal in the queue.
    # @param id [Integer] The ID of the publisher.
    # @param heartbeat_interval [Float] The interval in seconds between heartbeats.
    # @param tick_interval [Float] The base interval in seconds for sleeping during the loop.
    # @param logger [Logger] A logger for logging heartbeat and system status.
    # @param time [Time] Current time context.
    # @param process [Process] The process module for accessing system metrics.
    # @param kernel [Kernel] The kernel module for sleeping operations.
    # @return [Thread] The heartbeat thread.
    def create_heartbeat_thread(id:, hostname:, process_id:,
                                heartbeat_interval:, tick_interval:,
                                logger:, time:, process:, kernel:)
      Thread.new do
        Thread.current.name = "heartbeat"

        while !terminating?
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

                current_utc_time = time.now.utc

                previous_metrics = publisher.metrics
                last_updated_at = publisher.updated_at
                time_delta = [current_utc_time - last_updated_at, heartbeat_interval].max

                publisher_thread = Models::Thread
                  .select(
                    "COALESCE(SUM(queued_message_count), 0) AS queued_message_count,
                     COALESCE(SUM(publishing_message_count), 0) AS publishing_message_count,
                     COALESCE(SUM(published_message_count), 0) AS published_message_count,
                     COALESCE(SUM(failed_message_count), 0) AS failed_message_count,
                     MAX(updated_at) AS last_updated_at"
                  )
                  .where(hostname: hostname, process_id: process_id)
                  .group(:hostname, :process_id)
                  .take

                current_counts = {
                  "queued" => publisher_thread&.queued_message_count || 0,
                  "publishing" => publisher_thread&.publishing_message_count || 0,
                  "published" => publisher_thread&.published_message_count || 0,
                  "failed" => publisher_thread&.failed_message_count || 0
                }

                throughput_by_status =
                  current_counts.each_with_object({}) do |(status, count), h|
                    prev = previous_metrics[status]["count"] || 0
                    h[status] = ((count - prev) / time_delta).round(0)
                  end

                latency = 0

                if !publisher_thread.nil?
                  latency = (current_utc_time - publisher_thread.last_updated_at).round(0)
                end

                publisher.update!(
                  updated_at: current_utc_time,
                  metrics: {
                    "queued" => {
                      "count" => current_counts["queued"],
                      "throughput" => throughput_by_status["queued"]
                    },
                    "publishing" => {
                      "count" => current_counts["publishing"],
                      "throughput" => throughput_by_status["publishing"]
                    },
                    "published" => {
                      "count" => current_counts["published"],
                      "throughput" => throughput_by_status["published"]
                    },
                    "failed" => {
                      "count" => current_counts["failed"],
                      "throughput" => throughput_by_status["failed"]
                    },
                    "latency" => latency,
                    "cpu" => cpu,
                    "rss" => rss,
                    "rtt" => rtt
                  }
                )
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

    PUBLISH_MESSAGE_DEFAULTS = {
      concurrency: 1,
      tick_interval: 0.1,
      poll_interval: 5.0,
      heartbeat_interval: 5.0,
      log_level: 1
    }

    # Publish queued messages concurrently
    # @param name [String] The name of the publisher.
    # @param concurrency [Integer] The number of publisher threads.
    # @param tick_interval [Float] The tick interval in seconds.
    # @param poll_interval [Float] The poll interval in seconds.
    # @param heartbeat_interval [Float] The heartbeat interval in seconds.
    # @param logger [Logger] Logger for recording publishing activities.
    # @param time [Time] The current time context.
    # @param process [Process] The process module for system metrics.
    # @param kernel [Kernel] The kernel module for sleeping operations.
    # @yield [publisher, messages] Yields publisher and messages to be published.
    # @yieldparam publisher [Hash] A hash with keys `:id` and `:name` representing the publisher.
    # @yieldparam messages [Array<Hash>] An array of message hashes retrieved from the buffer.
    def publish_message(
      name: "#{::Socket.gethostname}:#{::Process.pid}",
      hostname: Socket.gethostname,
      process_id: Process.pid,
      concurrency: PUBLISH_MESSAGE_DEFAULTS[:concurrency],
      tick_interval: PUBLISH_MESSAGE_DEFAULTS[:tick_interval],
      poll_interval: PUBLISH_MESSAGE_DEFAULTS[:poll_interval],
      heartbeat_interval: PUBLISH_MESSAGE_DEFAULTS[:heartbeat_interval],
      logger: Logger.new($stdout, level: PUBLISH_MESSAGE_DEFAULTS[:log_level]),
      time: ::Time, process: ::Process, kernel: ::Kernel,
      &block
    )
      logger.info "Outboxer v#{Outboxer::VERSION} running in ruby #{RUBY_VERSION} " \
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      logger.info "Outboxer config " \
        "concurrency=#{concurrency}, " \
        "tick_interval=#{tick_interval} " \
        "poll_interval=#{poll_interval}, " \
        "heartbeat_interval=#{heartbeat_interval}, " \
        "log_level=#{logger.level}"

      publisher = create(
        name: name,
        concurrency: concurrency,
        tick_interval: tick_interval,
        poll_interval: poll_interval,
        heartbeat_interval: heartbeat_interval)

      heartbeat_thread = create_heartbeat_thread(
        id: publisher[:id], heartbeat_interval: heartbeat_interval, tick_interval: tick_interval,
        hostname: hostname, process_id: process_id,
        logger: logger, time: time, process: process, kernel: kernel)

      publisher_threads = Array.new(concurrency) do |index|
        create_publisher_thread(
          id: publisher[:id], index: index,
          hostname: hostname, process_id: process_id,
          poll_interval: poll_interval, tick_interval: tick_interval,
          logger: logger, process: process, kernel: kernel, time: time, &block)
      end

      signal_read, _signal_write = trap_signals

      while !terminating?
        if signal_read.wait_readable(tick_interval)
          handle_signal(id: publisher[:id], name: signal_read.gets.chomp, logger: logger)
        end
      end

      logger.info "Outboxer terminating"

      publisher_threads.each(&:join)

      heartbeat_thread.join

      delete(id: publisher[:id])

      logger.info "Outboxer terminated"
    end

    def pool(concurrency:)
      concurrency + 2 # (main + heartbeat)
    end

    # @param id [Integer] Publisher id.
    # @param index [Integer] Zero-based thread index (used for thread name).
    # @param poll_interval [Numeric] Seconds to wait when no messages found.
    # @param tick_interval [Numeric] Seconds between signal checks during sleep.
    # @param logger [Logger] Logger used for info/error/fatal messages.
    # @param process [Object] Process-like object passed to `Publisher.sleep`.
    # @param kernel [Object] Kernel object passed to `Publisher.sleep`.
    # @yieldparam publisher [Hash{Symbol=>Integer,String}] Publisher details,
    #   e.g., `{ id: Integer, name: String }`.
    # @yieldparam messages [Array<Hash>] Batch of messages to publish.
    # @return [Thread] The created publishing thread.
    def create_publisher_thread(id:, index:,
                                hostname:, process_id:,
                                poll_interval:, tick_interval:,
                                logger:, process:, kernel:, time:, &block)
      Thread.new do
        begin
          Thread.current.name = "publisher-#{index + 1}"
          # Thread.current.report_on_exception = true

          current_utc_time = time.now.utc

          ActiveRecord::Base.connection_pool.with_connection do
            Models::Thread.create!(
              hostname: hostname,
              process_id: process_id,
              thread_id: Thread.current.object_id,
              queued_message_count: 0,
              queued_message_count_last_updated_at: current_utc_time,
              publishing_message_count: 0,
              publishing_message_count_last_updated_at: current_utc_time,
              published_message_count: 0,
              published_message_count_last_updated_at: current_utc_time,
              failed_message_count: 0,
              failed_message_count_last_updated_at: current_utc_time,
              created_at: current_utc_time,
              updated_at: current_utc_time)
          end

          while !terminating?
            if publishing?
              begin
                published_message = Message.publish(logger: logger) do |message|
                  block.call({ id: id }, message)
                end
              rescue StandardError => error
                logger.error(
                  "#{error.class}: #{error.message}\n" \
                  "#{error.backtrace.join("\n")}")

                Publisher.sleep(
                  poll_interval,
                  tick_interval: tick_interval,
                  process: process,
                  kernel: kernel)
              else
                if published_message.nil?
                  Publisher.sleep(
                    poll_interval,
                    tick_interval: tick_interval,
                    process: process,
                    kernel: kernel)
                end
              end
            else
              Publisher.sleep(tick_interval, tick_interval: tick_interval,
                process: process, kernel: kernel)
            end
          end
        rescue ::Exception => error
          logger.fatal(
            "#{error.class}: #{error.message}\n" \
            "#{error.backtrace.join("\n")}")

          terminate(id: id)
        ensure
          logger.info "#{Thread.current.name} shutting down"
        end
      end
    end
  end
end
