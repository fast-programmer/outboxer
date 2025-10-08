module Outboxer
  module Models
    class MessageTotal < ::ActiveRecord::Base
      self.table_name = :outboxer_message_totals

      validates :status, :partition, presence: true
      validates :status, uniqueness: { scope: :partition }
    end
  end
end
