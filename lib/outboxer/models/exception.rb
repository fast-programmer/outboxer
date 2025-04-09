module Outboxer
  module Models
    class Exception < ::ActiveRecord::Base
      self.table_name = :outboxer_exceptions

      belongs_to :message

      has_many :frames, -> { order(index: :asc) }, foreign_key: "exception_id", dependent: :destroy

      validates :message_id, presence: true
    end
  end
end
