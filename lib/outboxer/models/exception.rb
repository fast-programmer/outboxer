module Outboxer
  module Models
    class Exception < ::ActiveRecord::Base
      self.table_name = :outboxer_exceptions

      belongs_to :message, class_name: "Outboxer::Models::Message"

      has_many :frames, -> { order(index: :asc) },
               class_name: "Outboxer::Models::Frame",
               foreign_key: "exception_id"

      validates :message_id, presence: true
    end
  end
end
