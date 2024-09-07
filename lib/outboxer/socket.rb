require 'socket'

module Outboxer
  module Socket
    extend self

    @hostname = ::Socket.gethostname

    def gethostname
      @hostname
    end
  end
end
