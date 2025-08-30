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

        opts.on("--sweep-interval SECS", Float, "Sweep interval in seconds") do |v|
          options[:sweep_interval] = v
        end

        opts.on("--sweep-retention SECS", Float, "Sweep retention in seconds") do |v|
          options[:sweep_retention] = v
        end

        opts.on("--sweep-batch-size SIZE", Integer, "Sweep batch size") do |v|
          options[:sweep_batch_size] = v
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
               sweep_interval:, sweep_retention:, sweep_batch_size:,
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

          Models::Counter.insert_all(
            [
              { name: "messages.published.count", publisher_id: nil, thread_id: nil,
                value: 0, created_at: current_utc_time, updated_at: current_utc_time },
              { name: "messages.published.count", publisher_id: publisher.id, thread_id: nil,
                value: 0, created_at: current_utc_time, updated_at: current_utc_time }
            ],
            unique_by: [:name, :publisher_id, :thread_id])

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
    def delete(id:, time: Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          current_utc_time = time.now.utc

          publisher = Models::Publisher.lock.find_by!(id: id)

          global_counter = Models::Counter
            .lock("FOR UPDATE")
            .where(name: "messages.published.count", publisher_id: nil, thread_id: nil)
            .first!

          publisher_counter = Models::Counter
            .lock("FOR UPDATE")
            .where(name: "messages.published.count", publisher_id: id, thread_id: nil)
            .first!

          thread_counters = Models::Counter.lock("FOR UPDATE")
            .where(name: "messages.published.count", publisher_id: id)
            .where.not(thread_id: nil)
            .to_a

          thread_counters_ids = thread_counters.map(&:id)
          thread_counters_value_sum = thread_counters.sum(&:value)

          global_counter.update!(
            value: global_counter.value + thread_counters_value_sum,
            updated_at: current_utc_time)

          publisher_counter.delete

          Models::Counter.where(id: thread_counters_ids).delete_all

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
    def create_heartbeat_thread(id:,
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

                global_counter = Models::Counter
                  .lock("FOR UPDATE")
                  .where(name: "messages.published.count", publisher_id: nil, thread_id: nil)
                  .first!

                publisher_counter = Models::Counter
                  .lock("FOR UPDATE")
                  .where(name: "messages.published.count", publisher_id: id, thread_id: nil)
                  .first!

                thread_counters = Models::Counter.lock("FOR UPDATE")
                  .where(name: "messages.published.count", publisher_id: id)
                  .where.not(thread_id: nil)
                  .to_a

                thread_counters_value_sum = thread_counters.sum(&:value)

                global_counter.update!(
                  value: global_counter.value + thread_counters_value_sum,
                  updated_at: current_utc_time)

                publisher_counter.value = publisher_counter.value + thread_counters_value_sum
                publisher_counter.updated_at = current_utc_time

                elapsed = publisher_counter.updated_at - publisher_counter.updated_at_was
                throughput = (
                  (publisher_counter.value - publisher_counter.value_was) / elapsed
                ).round

                publisher_counter.save!

                Models::Counter
                  .where(id: thread_counters.map(&:id))
                  .update_all(["value = 0, updated_at = ?", current_utc_time])

                last_queued_message = Models::Message
                  .where(status: Message::Status::QUEUED)
                  .where(publisher_id: id)
                  .order(published_at: :desc)
                  .first

                latency = if last_queued_message.nil?
                            0
                          else
                            (current_utc_time - last_queued_message.queued_at).to_i
                          end

                publisher.update!(
                  updated_at: current_utc_time,
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

    PUBLISH_MESSAGE_DEFAULTS = {
      concurrency: 1,
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
    # @param concurrency [Integer] The number of publisher threads.
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
    def publish_message(
      name: "#{::Socket.gethostname}:#{::Process.pid}",
      concurrency: PUBLISH_MESSAGE_DEFAULTS[:concurrency],
      tick_interval: PUBLISH_MESSAGE_DEFAULTS[:tick_interval],
      poll_interval: PUBLISH_MESSAGE_DEFAULTS[:poll_interval],
      heartbeat_interval: PUBLISH_MESSAGE_DEFAULTS[:heartbeat_interval],
      sweep_interval: PUBLISH_MESSAGE_DEFAULTS[:sweep_interval],
      sweep_retention: PUBLISH_MESSAGE_DEFAULTS[:sweep_retention],
      sweep_batch_size: PUBLISH_MESSAGE_DEFAULTS[:sweep_batch_size],
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
        "sweep_interval=#{sweep_interval}, " \
        "sweep_retention=#{sweep_retention}, " \
        "sweep_batch_size=#{sweep_batch_size}, " \
        "log_level=#{logger.level}"

      Setting.create_all

      publisher = create(
        name: name,
        concurrency: concurrency,
        tick_interval: tick_interval,
        poll_interval: poll_interval,
        heartbeat_interval: heartbeat_interval,
        sweep_interval: sweep_interval,
        sweep_retention: sweep_retention,
        sweep_batch_size: sweep_batch_size)

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

      publisher_threads = Array.new(concurrency) do |index|
        create_publisher_thread(
          id: publisher[:id], name: name, index: index,
          poll_interval: poll_interval, tick_interval: tick_interval,
          logger: logger, time: time, process: process, kernel: kernel, &block)
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
      sweeper_thread.join

      delete(id: publisher[:id], time: time)

      logger.info "Outboxer terminated"
    end

    def pool(concurrency:)
      concurrency + 3 # (main + heartbeat + sweeper)
    end

    # @param id [Integer] Publisher id.
    # @param name [String] Publisher name.
    # @param index [Integer] Zero-based thread index (used for thread name).
    # @param poll_interval [Numeric] Seconds to wait when no messages found.
    # @param tick_interval [Numeric] Seconds between signal checks during sleep.
    # @param logger [Logger] Logger used for info/error/fatal messages.
    # @param time [Time] Module used for fetching current UTC time.
    # @param process [Object] Process-like object passed to `Publisher.sleep`.
    # @param kernel [Object] Kernel object passed to `Publisher.sleep`.
    # @yieldparam publisher [Hash{Symbol=>Integer,String}] Publisher details,
    #   e.g., `{ id: Integer, name: String }`.
    # @yieldparam messages [Array<Hash>] Batch of messages to publish.
    # @return [Thread] The created publishing thread.
    def create_publisher_thread(id:, name:, index:,
                                poll_interval:, tick_interval:,
                                logger:, time:, process:, kernel:, &block)
      Thread.new do
        begin
          Thread.current.name = "publisher-#{index + 1}"

          current_utc_time = time.now.utc

          ActiveRecord::Base.connection_pool.with_connection do
            Models::Counter.insert_all(
              [
                { name: "messages.published.count",
                  publisher_id: id,
                  thread_id: Thread.current.object_id,
                  value: 0,
                  created_at: current_utc_time,
                  updated_at: current_utc_time }
              ],
              unique_by: [:name, :publisher_id, :thread_id]
            )
          end

          while !terminating?
            messages = []

            begin
              messages = buffer_messages(id: id, name: name, limit: 1)
            rescue StandardError => error
              logger.error(
                "#{error.class}: #{error.message}\n" \
                "#{error.backtrace.join("\n")}")
            end

            if messages.any?
              begin
                block.call({ id: id, name: name }, messages[0])
              rescue StandardError => error
                logger.error(
                  "#{error.class}: #{error.message}\n" \
                  "#{error.backtrace.join("\n")}")

                Publisher.update_messages(
                  id: id,
                  failed_messages: [
                    {
                      id: messages[0][:id],
                      exception: {
                        class_name: error.class.name,
                        message_text: error.message,
                        backtrace: error.backtrace
                      }
                    }
                  ])
              rescue ::Exception => error
                logger.fatal(
                  "#{error.class}: #{error.message}\n" \
                  "#{error.backtrace.join("\n")}")

                Publisher.update_messages(
                  id: id,
                  failed_messages: [
                    {
                      id: messages[0][:id],
                      exception: {
                        class_name: error.class.name,
                        message_text: error.message,
                        backtrace: error.backtrace
                      }
                    }
                  ])

                terminate(id: id)
              else
                Outboxer::Publisher.update_messages(
                  id: id, published_message_ids: [messages[0][:id]])
              end
            else
              Publisher.sleep(
                poll_interval,
                tick_interval: tick_interval,
                process: process,
                kernel: kernel)
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

        while !terminating?
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

    # Marks queued messages as buffered.
    #
    # @param id [Integer] the ID of the publisher.
    # @param name [String] the name of the publisher.
    # @param limit [Integer] the number of messages to buffer.
    # @param time [Time] current time context used to update timestamps.
    # @return [Array<Hash>] buffered messages.
    def buffer_messages(id:, name:, limit: 1, time: ::Time)
      current_utc_time = time.now.utc
      messages = []

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          messages = Models::Message
            .where(status: Message::Status::QUEUED)
            .order(updated_at: :asc)
            .limit(limit)
            .lock("FOR UPDATE SKIP LOCKED")
            .pluck(:id, :messageable_type, :messageable_id)

          message_ids = messages.map(&:first)

          updated_rows = Models::Message
            .where(id: message_ids, status: Message::Status::QUEUED)
            .update_all(
              status: Message::Status::PUBLISHING,
              updated_at: current_utc_time,
              buffered_at: current_utc_time,
              publisher_id: id,
              publisher_name: name)

          if updated_rows != message_ids.size
            raise ArgumentError, "Some messages not buffered"
          end
        end
      end

      messages.map do |message_id, messageable_type, messageable_id|
        {
          id: message_id,
          messageable_type: messageable_type,
          messageable_id: messageable_id
        }
      end
    end

    # Updates messages as published or failed.
    #
    # @param id [Integer]
    # @param published_message_ids [Array<Integer>]
    # @param failed_messages [Array<Hash>] Array of failed message hashes:
    #   [
    #     {
    #       id: Integer,
    #       exception: {
    #         class_name: String,
    #         message_text: String,
    #         backtrace: Array<String>
    #       }
    #     }
    #   ]
    # @param time [Time]
    # @return [nil]
    def update_messages(id:, published_message_ids: [], failed_messages: [],
                        time: ::Time)
      current_utc_time = time.now.utc

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          if published_message_ids.any?
            messages = Models::Message
              .where(id: published_message_ids, status: Message::Status::PUBLISHING)
              .lock("FOR UPDATE")
              .pluck(:id)

            if messages.size != published_message_ids.size
              raise ArgumentError, "Some messages publishing not locked for update"
            end

            # updated_rows = Models::Message
            #   .where(status: Status::PUBLISHING, id: published_message_ids)
            #   .update_all(
            #     status: Message::Status::PUBLISHED,
            #     updated_at: current_utc_time,
            #     published_at: current_utc_time,
            #     publisher_id: id)

            # if updated_rows != published_message_ids.size
            #   raise ArgumentError, "Some messages publishing not updated to published"
            # end

            Models::Frame
              .joins(:exception)
              .where(exception: { message_id: published_message_ids })
              .delete_all

            Models::Exception.where(message_id: published_message_ids).delete_all

            deleted_rows = Models::Message.where(id: published_message_ids).delete_all

            if deleted_rows != published_message_ids.size
              raise ArgumentError, "Some messages publishing not deleted"
            end

            Models::Counter
              .where(
                publisher_id: id,
                thread_id: Thread.current.object_id,
                name: "messages.published.count")
              .update_all([
                "value = value + ?, updated_at = ?",
                published_message_ids.count, time.now.utc
              ])
          end

          failed_messages.each do |failed_message|
            message = Models::Message
              .lock("FOR UPDATE")
              .find_by!(id: failed_message[:id], status: Message::Status::PUBLISHING)

            message.update!(status: Message::Status::FAILED, updated_at: current_utc_time)

            exception = message.exceptions.create!(
              class_name: failed_message[:exception][:class_name],
              message_text: failed_message[:exception][:message_text],
              created_at: current_utc_time)

            (failed_message[:exception][:backtrace] || []).each_with_index do |frame, index|
              exception.frames.create!(index: index, text: frame)
            end
          end
        end
      end

      nil
    end
  end
end
