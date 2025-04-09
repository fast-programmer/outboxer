module Outboxer
  module Models
    class Frame < ::ActiveRecord::Base
      self.table_name = :outboxer_frames
      # @!attribute [rw] index
      #   @return [Integer] The position of the frame.

      # @!attribute [rw] text
      #   @return [String] The content of the frame.

      # @!attribute [rw] exception_id
      #   @return [Integer] The exception associated with the frame.

      validates :index,
        presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      validates :text, presence: true

      validates :exception_id, presence: true

      # @!method exception
      #   @return [Outboxer::Models::Exception] The exception that this frames belongs to.
      belongs_to :exception, foreign_key: "exception_id"
    end
  end
end
