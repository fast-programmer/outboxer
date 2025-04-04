require "optparse"

module Outboxer
  module Publisher
    module_function

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

        opts.on("-b", "--buffer SIZE", Integer, "Buffer") do |v|
          options[:buffer] = v
        end

        opts.on("-c", "--concurrency SIZE", Integer, "Concurrency") do |v|
          options[:concurrency] = v
        end

        opts.on("-t", "--tick SECS", Float, "Tick interval in seconds") do |v|
          options[:tick] = v
        end

        opts.on("-p", "--poll SECS", Float, "Poll interval in seconds") do |v|
          options[:poll] = v
        end

        opts.on("-a", "--heartbeat SECS", Float, "Heartbeat interval in seconds") do |v|
          options[:heartbeat] = v
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

    def create(name:, buffer:, concurrency:,
               tick:, poll:, heartbeat:, time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          current_utc_time = time.now.utc

          publisher = Models::Publisher.create!(
            name: name,
            status: Status::PUBLISHING,
            settings: {
              "buffer" => buffer,
              "concurrency" => concurrency,
              "tick" => tick,
              "poll" => poll,
              "heartbeat" => heartbeat
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

    def stop(id:, time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock.find(id)
          publisher.update!(status: Status::STOPPED, updated_at: time.now.utc)

          @status = Status::STOPPED
        end
      end
    end

    def continue(id:, time: ::Time)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          publisher = Models::Publisher.lock.find(id)

          publisher.update!(status: Status::PUBLISHING, updated_at: time.now.utc)

          @status = Status::PUBLISHING
        end
      end
    end

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

    # :nocov:
    def sleep(duration, start_time:, tick:, signal_read:, process:, kernel:)
      while (@status != Status::TERMINATING) &&
            ((process.clock_gettime(process::CLOCK_MONOTONIC) - start_time) < duration) &&
            !signal_read.wait_readable(0)
        kernel.sleep(tick)
      end
    end
    # :nocov:

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

    def create_publisher_threads(id:, name:,
                                 queue:, concurrency:,
                                 logger:, &block)
      concurrency.times.each_with_index.map do |_, index|
        Thread.new do
          Thread.current.name = "publisher-#{index + 1}"

          while (message = queue.pop)
            break if message.nil?

            publish_message(
              id: id, name: name, buffered_message: message,
              logger: logger, &block)
          end
        end
      end
    end

    def buffer_messages(id:, name:,
                        queue:, buffer:, poll:, tick:,
                        signal_read:, logger:, process:, kernel:)
      buffer_limit = buffer - queue.size

      if buffer_limit > 0
        buffered_messages = Message.buffer(
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

    def create_heartbeat_thread(id:,
                                heartbeat:, tick:, signal_read:,
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
              heartbeat,
              signal_read: signal_read,
              start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
              tick: tick,
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
              heartbeat,
              signal_read: signal_read,
              start_time: process.clock_gettime(process::CLOCK_MONOTONIC),
              tick: tick,
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
      buffer: 100,
      concurrency: 1,
      tick: 0.1,
      poll: 5.0,
      heartbeat: 5.0,
      log_level: 1
    }

    def publish(
      name: "#{::Socket.gethostname}:#{::Process.pid}",
      buffer: PUBLISH_DEFAULTS[:buffer],
      concurrency: PUBLISH_DEFAULTS[:concurrency],
      tick: PUBLISH_DEFAULTS[:tick],
      poll: PUBLISH_DEFAULTS[:poll],
      heartbeat: PUBLISH_DEFAULTS[:heartbeat],
      logger: Logger.new($stdout, level: PUBLISH_DEFAULTS[:log_level]),
      time: ::Time, process: ::Process, kernel: ::Kernel,
      &block
    )
      Thread.current.name = "main"

      logger.info "Outboxer v#{Outboxer::VERSION} running in ruby #{RUBY_VERSION} " \
        "(#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION[0, 10]}) [#{RUBY_PLATFORM}]"

      logger.info "Outboxer config buffer=#{buffer}, concurrency=#{concurrency}, tick=#{tick}, " \
        "poll=#{poll}, heartbeat=#{heartbeat}, log_level=#{logger.level}"

      Setting.create_all

      queue = Queue.new

      publisher = create(
        name: name, buffer: buffer, concurrency: concurrency,
        tick: tick, poll: poll, heartbeat: heartbeat)
      id = publisher[:id]

      publisher_threads = create_publisher_threads(
        id: id, name: name, queue: queue, concurrency: concurrency,
        logger: logger, &block)

      signal_read, _signal_write = trap_signals

      heartbeat_thread = create_heartbeat_thread(
        id: id,
        heartbeat: heartbeat,
        tick: tick,
        signal_read: signal_read,
        logger: logger,
        time: time, process: process, kernel: kernel)

      loop do
        case @status
        when Status::PUBLISHING
          buffer_messages(
            id: id, name: name,
            queue: queue, buffer: buffer,
            poll: poll, tick: tick,
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

    def publish_message(id:, name:, buffered_message:, logger:, &block)
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
