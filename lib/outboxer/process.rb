module Outboxer
  module Process
    extend self

    @pid = ::Process.pid

    def pid
      @pid
    end
  end
end
