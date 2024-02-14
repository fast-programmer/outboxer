module Outboxer
  module Models
    class Frame < ::ActiveRecord::Base
      self.table_name = :outboxer_frames

      belongs_to :exception, class_name: 'Outboxer::Models::Exception', foreign_key: 'exception_id'
      validates :exception_id, presence: true

      validates :file_name, presence: true
      validates :line_number,
        presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      validates :method_name, presence: true, allow_nil: true
    end
  end
end
