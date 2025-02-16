module Outboxer
  class Exception < ::ActiveRecord::Base
    self.table_name = :outboxer_exceptions

    belongs_to :message, class_name: "Outboxer::Message"

    has_many :frames, -> { order(index: :asc) },
      class_name: "Outboxer::Frame",
      foreign_key: "exception_id"

    validates :message_id, presence: true
  end
end
