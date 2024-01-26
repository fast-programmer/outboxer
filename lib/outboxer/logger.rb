require 'logger'
require 'thread'

module Outboxer
  class Logger < ::Logger
    COLORS = [
      "\e[33m",  # Yellow
      "\e[35m",  # Magenta
      "\e[36m",  # Cyan
      "\e[37m",  # White
      "\e[90m",  # Grey
      "\e[34m",  # Blue
      "\e[94m",  # Bright Blue
      "\e[95m",  # Bright Magenta
      "\e[96m",  # Bright Cyan
      "\e[97m",  # Bright White
      "\e[93m",  # Bright Yellow
      "\e[91m",  # Bright Red (can be used if not indicating error)
      "\e[92m",  # Bright Green (can be used if not indicating success)
      "\e[100m", # Background Grey
      "\e[44m",  # Background Blue
      "\e[45m",  # Background Magenta
      "\e[46m",  # Background Cyan
      "\e[47m",  # Background White
      "\e[104m", # Background Bright Blue
      "\e[105m", # Background Bright Magenta
      "\e[106m", # Background Bright Cyan
      "\e[107m", # Background Bright White
      "\e[103m", # Background Bright Yellow
      "\e[101m", # Background Bright Red (can be used if not indicating error)
      "\e[102m"  # Background Bright Green (can be used if not indicating success)
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
