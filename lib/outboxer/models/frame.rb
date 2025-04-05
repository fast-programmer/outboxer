module Outboxer
  module Models
    class Frame < ::ActiveRecord::Base
      self.table_name = :outboxer_frames

      belongs_to :exception, foreign_key: "exception_id"
      validates :exception_id, presence: true

      validates :index,
        presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :text, presence: true
    end
  end
end
