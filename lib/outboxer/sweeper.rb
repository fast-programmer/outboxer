# frozen_string_literal: true

require "securerandom"
require "logger"
require "optparse"
require "active_support/number_helper"

module Outboxer
  module Sweeper
    module_function

    SWEEP_DEFAULTS = {
      batch_size: 1_000,
      concurrency: 10,
      retention_seconds: 60,
      tick_interval: 1
    }

    def parse_cli_options(argv)
      options = {}

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: outboxer_sweep [options]"

        opts.on("--environment ENV", "Environment (default: development)") do |v|
          options[:environment] = v
        end

        opts.on("--batch-size SIZE", Integer, "Batch size (default: 1000)") do |v|
          options[:batch_size] = v
        end

        opts.on("--concurrency COUNT", Integer, "Concurrency (default: 5)") do |v|
          options[:concurrency] = v
        end

        opts.on("--retention-seconds SECONDS", Integer, "Retention in seconds") do |v|
          options[:retention_seconds] = v
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
      metrics = {
        memory_kb: `ps -o rss= -p #{Process.pid}`.to_i,
        cpu_percent: `ps -o %cpu= -p #{Process.pid}`.strip.to_f
      }

      logger.info "[metrics] memory=#{metrics[:memory_kb]}KB cpu=#{metrics[:cpu_percent]}%"
    end

    def sweep(batch_size: SWEEP_DEFAULTS[:batch_size],
              concurrency: SWEEP_DEFAULTS[:concurrency],
              retention_seconds: SWEEP_DEFAULTS[:retention_seconds],
              tick_interval: SWEEP_DEFAULTS[:tick_interval],
              logger: Outboxer::Logger.new($stdout))
      signal_reader, _signal_writer = trap_signals

      threads = spawn_workers(concurrency, retention_seconds, batch_size, logger)

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      while @status != :terminating
        if signal_reader.wait_readable(tick_interval)

          @status = case signal_reader.gets.chomp
                    when "INT", "TERM" then :terminating
                    else
                      @status
                    end
        end
      end

      threads.each(&:join)

      finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed = finished_at - started_at

      logger.info "[main] duration: #{elapsed.round(2)}s"
      logger.info "[main] done"
    end

    def trap_signals
      reader, writer = IO.pipe

      %w[INT TERM].each do |signal|
        Signal.trap(signal) do
          writer.puts(signal)
        end
      end

      [reader, writer]
    end

    def spawn_workers(concurrency, retention_seconds, batch_size, logger)
      Array.new(concurrency) do |index|
        Thread.new do
          while @status != :terminating
            begin
              cutoff = Time.now - retention_seconds

              ActiveRecord::Base.connection_pool.with_connection do
                ActiveRecord::Base.transaction do
                  ids = Outboxer::Models::Message
                    .where("updated_at <= ?", cutoff)
                    .where(status: "published")
                    .limit(batch_size)
                    .pluck(:id)

                  deleted_count = Outboxer::Models::Message.where(id: ids).delete_all
                  break if deleted_count.zero?

                  setting_name = "messages.published.count.historic"
                  setting = Models::Setting.lock("FOR UPDATE").find_by!(name: setting_name)
                  setting.update!(value: setting.value.to_i + deleted_count)
                end
              end
            rescue StandardError => error
              logger.error "[thread-#{index}] #{error.class}: #{error.message}"
            end
          end
        end
      end
    end
  end
end
