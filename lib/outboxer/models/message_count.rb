module Outboxer
  module Models
    class MessageCount < ::ActiveRecord::Base
      self.table_name = :outboxer_message_counts

      validates :status, :partition, presence: true
    end
  end
end
