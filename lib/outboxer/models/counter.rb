module Outboxer
  module Models
    class Counter < ::ActiveRecord::Base
      self.table_name = :outboxer_counters
    end
  end
end
