module Outboxer
  module Models
    class MessageTotal < ::ActiveRecord::Base
      self.table_name = :outboxer_message_totals

      validates :status, :partition, presence: true
    end
  end
end
