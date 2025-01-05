require "logger"

module Outboxer
  class Logger < ::Logger
    def initialize(*args, **kwargs)
      super(*args, **kwargs)

      self.formatter = proc do |severity, datetime, _progname, msg|
        current_thread = ::Thread.current

        pid = current_thread["outboxer_pid"] ||= ::Process.pid

        tid = current_thread["outboxer_tid"] ||=
          (current_thread.name || (current_thread.object_id ^ pid).to_s(36))

        "#{datetime.utc.iso8601(3)} pid=#{pid} tid=#{tid} #{severity}: #{msg}\n"
      end
    end
  end
end
