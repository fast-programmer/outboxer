module Outboxer
  module Models
    class MessageCounts < ::ActiveRecord::Base
      self.table_name = :outboxer_message_counts

      validates :status, :partition, presence: true
      validates :status, uniqueness: { scope: :partition }
    end
  end
end
