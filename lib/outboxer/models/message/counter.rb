module Outboxer
  module Models
    class Message
      class Counter < ActiveRecord::Base
        self.table_name = "outboxer_message_counters"

        HISTORIC_HOSTNAME   = "historic"
        HISTORIC_PROCESS_ID = 0
        HISTORIC_THREAD_ID  = 0
      end
    end
  end
end
