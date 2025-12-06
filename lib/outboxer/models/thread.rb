module Outboxer
  module Models
    class Thread < ActiveRecord::Base
      self.table_name = "outboxer_threads"

      HISTORIC_HOSTNAME   = "historic"
      HISTORIC_PROCESS_ID = 0
      HISTORIC_THREAD_ID  = 0
    end
  end
end
