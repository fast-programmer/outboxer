require 'logger'
require 'thread'

module Outboxer
  class Logger < ::Logger
    COLORS = [
      "\e[33m", # Yellow
      "\e[35m", # Magenta
      "\e[36m", # Cyan
      "\e[37m", # White
      "\e[90m"  # Grey
    ]

    DEBUG = ::Logger::DEBUG
    INFO = ::Logger::INFO
    WARN = ::Logger::WARN
    ERROR = ::Logger::ERROR
    FATAL = ::Logger::FATAL
    UNKNOWN = ::Logger::UNKNOWN

    def initialize(output, **args)
      super(output, **args)

      @thread_color_map = {}
      @mutex = Mutex.new

      self.formatter = proc do |severity, datetime, progname, msg|
        thread_color = assign_color_to_thread(Thread.current.object_id)

        "#{thread_color}[#{datetime}] #{severity} -- #{progname}: #{msg}\e[0m\n"
      end
    end

    private

    def assign_color_to_thread(thread_id)
      @mutex.synchronize do
        @thread_color_map[thread_id] ||= COLORS[next_color_index]
      end
    end

    def next_color_index
      @thread_color_map.size % COLORS.size
    end
  end
end
