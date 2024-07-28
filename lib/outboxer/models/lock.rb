module Outboxer
  module Models
    class Lock < ActiveRecord::Base
      self.table_name = :outboxer_locks
    end
  end
end
