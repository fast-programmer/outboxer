require "active_record"
require "kaminari"

require_relative "outboxer/version"
require_relative "outboxer/railtie" if defined?(Rails)

require_relative "outboxer/models/setting"

require_relative "outboxer/models/frame"
require_relative "outboxer/models/exception"
require_relative "outboxer/models/message"

require_relative "outboxer/models/publisher"
require_relative "outboxer/models/signal"

require_relative "outboxer/logger"
require_relative "outboxer/database"
require_relative "outboxer/message"
require_relative "outboxer/messages"
require_relative "outboxer/publisher"
require_relative "outboxer/publishers"

module Outboxer
  extend self

  def format_duration(start_time:, end_time: ::Process.clock_gettime(::Process::CLOCK_MONOTONIC))
    units = [
      { name: "y", scale: 1.0 / 31_536_000 },  # 1 year = 31,536,000 seconds (365 days)
      { name: "mo", scale: 1.0 / 2_592_000 },  # 1 month = 2,592,000 seconds (30 days)
      { name: "w", scale: 1.0 / 604_800 },     # 1 week = 604,800 seconds
      { name: "d", scale: 1.0 / 86_400 },      # 1 day = 86,400 seconds
      { name: "h", scale: 1.0 / 3_600 },       # 1 hour = 3,600 seconds
      { name: "min", scale: 1.0 / 60 },        # 1 minute = 60 seconds
      { name: "s", scale: 1 },                 # 1 second = 1 second
      { name: "ms", scale: 1_000 },            # 1 millisecond = 1/1,000 second
      { name: "µs", scale: 1_000_000 },        # 1 microsecond = 1/1,000,000 second
      { name: "ns", scale: 1_000_000_000 }     # 1 nanosecond = 1/1,000,000,000 second
    ].freeze

    duration = end_time - start_time

    units.each do |unit|
      value = duration * unit[:scale]
      if value >= 1 || unit[:name] == "ns"
        return "#{value.round(3)}#{unit[:name]}"
      end
    end
  end

  def format_duration_ms(start_time:, end_time: ::Process.clock_gettime(::Process::CLOCK_MONOTONIC))
    duration_seconds = end_time - start_time
    duration_ms = duration_seconds * 1_000

    "#{duration_ms.round(3)}ms"
  end
end
