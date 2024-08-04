require 'logger'

module Outboxer
  class Logger < ::Logger
    def initialize(*args, **kwargs)
      super(*args, **kwargs)

      self.formatter = proc do |severity, datetime, progname, msg|
        formatted_time = datetime.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
        pid = ::Process.pid
        tid = Thread.current.object_id.to_s(36)
        level = severity
        "#{formatted_time} pid=#{pid} tid=#{tid} #{level}: #{msg}\n"
      end
    end
  end
end
