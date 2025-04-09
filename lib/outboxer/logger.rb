require "logger"

module Outboxer
  # Advanced log lines including timestamp, process ID and thread ID.
  #
  # @example Usage
  #   logger = Outboxer::Logger.new(STDOUT)
  #   logger.info("Hello World")
  #
  # @example Output
  #   2025-04-10T12:34:56.789Z pid=12345 tid=8cd9f pid=12345 tid=8cd9f INFO: Hello World
  #
  class Logger < ::Logger
    # Initializes a new Logger instance with a custom format.
    # @param args [Array] Arguments that are passed to the standard Logger initializer.
    # @param kwargs [Hash] Keyword arguments that are passed to the standard Logger initializer.
    def initialize(*args, **kwargs)
      super

      self.formatter = proc do |severity, datetime, _progname, msg|
        current_thread = ::Thread.current

        pid = current_thread["outboxer_pid"] ||= ::Process.pid

        tid = current_thread["outboxer_tid"] ||=
          current_thread.name || (current_thread.object_id ^ pid).to_s(36)

        "#{datetime.utc.iso8601(3)} pid=#{pid} tid=#{tid} #{severity}: #{msg}\n"
      end
    end
  end
end
