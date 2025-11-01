# frozen_string_literal: true

require "securerandom"
require "logger"
require "optparse"
require "ostruct"
require "active_support/number_helper"

module Outboxer
  module Loader
    module_function

    LOAD_DEFAULTS = {
      batch_size: 1_000,
      concurrency: 5,
      size: 1,
      tick_interval: 1
    }

    def parse_cli_options(argv)
      options = {}

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: outboxer_load [options]"

        opts.on("--environment ENV", "Environment (default: development)") do |v|
          options[:environment] = v
        end

        opts.on("--batch-size SIZE", Integer, "Batch size (default: 1000)") do |v|
          options[:batch_size] = v
        end

        opts.on("--concurrency COUNT", Integer, "Concurrency (default: 5)") do |v|
          options[:concurrency] = v
        end

        opts.on("--size SIZE", Integer, "Number of messages to load (default: 1)") do |v|
          options[:size] = v
        end

        opts.on("--tick-interval SECONDS", Float, "Tick interval in seconds (default: 1)") do |v|
          options[:tick_interval] = v
        end

        opts.on("--help", "Show this help message") do
          puts opts
          exit
        end
      end

      parser.parse!(argv)

      options
    end

    def display_metrics(logger)
      memory_kb = `ps -o rss= -p #{Process.pid}`.to_i
      cpu_percent = `ps -o %cpu= -p #{Process.pid}`.strip.to_f
      logger.info "[metrics] memory=#{memory_kb}KB cpu=#{cpu_percent}%"
    end

    def load(batch_size: LOAD_DEFAULTS[:batch_size],
             concurrency: LOAD_DEFAULTS[:concurrency],
             size: LOAD_DEFAULTS[:size],
             tick_interval: LOAD_DEFAULTS[:tick_interval],
             logger: Outboxer::Logger.new($stdout))
      status = :loading

      Signal.trap("INT")  { status = :terminating }
      Signal.trap("TERM") { status = :terminating }
      Signal.trap("TSTP") { status = :stopped }
      Signal.trap("CONT") { status = :loading }

      queue = Queue.new
      threads = spawn_workers(concurrency, queue, logger)

      enqueued = 0
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      while enqueued < size
        case status
        when :terminating
          break
        when :stopped
          sleep tick_interval
        when :loading
          messageables = Array.new(batch_size) do
            OpenStruct.new(class: OpenStruct.new(name: "Event"), id: SecureRandom.hex(3))
          end

          queue << messageables
          enqueued += messageables.size

          # logger.info "[main] enqueued #{enqueued}/#{size}" if (enqueued % (batch_size * 2)).zero?
        end
      end

      queue.close

      threads.each(&:kill)

      finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed = finished_at - started_at
      rate = (enqueued / elapsed).round(2)
      formatted_rate = ActiveSupport::NumberHelper.number_to_delimited(rate)

      logger.info "[main] duration: #{elapsed.round(2)}s"
      logger.info "[main] throughput: #{formatted_rate} messages/sec"
      logger.info "[main] done"
    end

    def spawn_workers(concurrency, queue, logger)
      Array.new(concurrency) do |index|
        Thread.new do
          while (messageables = queue.pop)
            messageables.each do |messageable|
              Outboxer::Message.queue(messageable: messageable)
            rescue StandardError => error
              logger.error "[thread-#{index}] #{error.class}: #{error.message}"

              sleep 1
            end
          end
        end
      end
    end
  end
end
