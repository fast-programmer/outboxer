# frozen_string_literal: true

require "securerandom"
require "logger"
require "optparse"
require "active_support/number_helper"

module Outboxer
  module Loader
    module_function

    LOAD_DEFAULTS = {
      batch_size: 1_000,
      concurrency: 5,
      size: 1_000_000,
      tick_interval: 1
    }

    def parse_cli_options(argv)
      options = {}

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: outboxer_load [options]"

        opts.on("-e", "--environment ENV", "Environment (default: development)") do |v|
          options[:environment] = v
        end

        opts.on("-b", "--batch-size SIZE", Integer, "Batch size (default: 1000)") do |v|
          options[:batch_size] = v
        end

        opts.on("-c", "--concurrency COUNT", Integer, "Concurrency (default: 5)") do |v|
          options[:concurrency] = v
        end

        opts.on("-s", "--size SIZE", Integer, "Number of messages to load") do |v|
          options[:size] = v
        end

        opts.on("-t", "--tick-interval SECONDS", Float, "Tick interval in seconds (default: 1)") do |v|
          options[:tick_interval] = v
        end

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          exit
        end
      end

      parser.parse!(argv)

      options
    end

    def display_metrics(logger)
      metrics = {
        memory_kb: `ps -o rss= -p #{Process.pid}`.to_i,
        cpu_percent: `ps -o %cpu= -p #{Process.pid}`.strip.to_f
      }

      logger.info "[metrics] memory=#{metrics[:memory_kb]}KB cpu=#{metrics[:cpu_percent]}%"
    end

    def load(batch_size: LOAD_DEFAULTS[:batch_size],
             concurrency: LOAD_DEFAULTS[:concurrency],
             size: LOAD_DEFAULTS[:size],
             tick_interval: LOAD_DEFAULTS[:tick_interval],
             logger: Outboxer::Logger.new($stdout))
      status = :loading
      reader, _writer = trap_signals
      queue = SizedQueue.new(concurrency)
      threads = spawn_workers(concurrency, queue, logger)

      enqueued = 0
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      while enqueued < size
        status = read_status(reader) || status

        case status
        when :terminating
          break
        when :stopped
          sleep tick_interval
        when :loading
          batch = Array.new(batch_size) do
            {
              messageable_type: "Event",
              messageable_id: SecureRandom.hex(3),
              status: "queued",
              queued_at: Time.current
            }
          end
          queue << batch
          enqueued += batch.size
          # logger.info "[main] enqueued #{enqueued}/#{size}" if (enqueued % (batch_size * 2)).zero?
        end

        # display_metrics(logger)
      end

      concurrency.times { queue << nil }
      threads.each(&:join)

      finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed = finished_at - started_at
      rate = (enqueued / elapsed).round(2)
      formatted_rate = ActiveSupport::NumberHelper.number_to_delimited(rate)

      logger.info "[main] duration: #{elapsed.round(2)}s"
      logger.info "[main] throughput: #{formatted_rate} messages/sec"
      logger.info "[main] done"
    end

    def trap_signals
      reader, writer = IO.pipe

      %w[INT TERM TSTP CONT].each do |signal|
        Signal.trap(signal) { writer.puts(signal) }
      end

      [reader, writer]
    end

    def read_status(reader)
      line = reader.ready? ? reader.gets&.strip : nil

      case line
      when "INT", "TERM" then :terminating
      when "TSTP"        then :stopped
      when "CONT"        then :loading
      end
    end

    def spawn_workers(concurrency, queue, logger)
      Array.new(concurrency) do |index|
        Thread.new do
          loop do
            batch = queue.pop
            break if batch.nil?

            Outboxer::Models::Message.insert_all(batch)
            # logger.info "[thread-#{index}] inserted #{batch.size}"
          rescue StandardError => error
            logger.error "[thread-#{index}] #{error.class}: #{error.message}"
          end
        end
      end
    end
  end
end
