module Outboxer
  module Models
    class Exception < ::ActiveRecord::Base
      self.table_name = :outboxer_exceptions

      validates :message_id, presence: true

      # @!attribute [rw] class_name
      #   @return [String] Class name of the exception.

      # @!attribute [rw] message_text
      #   @return [String] Detailed message of the exception.

      # @!attribute [rw] message_id
      #   @return [Integer] Message id associated with this exception.

      # @!attribute [rw] created_at
      #   @return [DateTime] The date and time when the exception was created.

      # @!method message
      #   @return [Outboxer::Models::Message] The message that this exception belongs to.
      belongs_to :message

      # @!method frames
      #   @return [Outboxer::Models::Frame::ActiveRecord_Associations_CollectionProxy]
      #   Stack frames for this exception.
      has_many :frames, -> { order(index: :asc) }, foreign_key: "exception_id", dependent: :destroy
    end
  end
end
