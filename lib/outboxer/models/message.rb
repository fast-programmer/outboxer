require "active_record"

module Outboxer
  module Models
    # Represents a message in the outbox.
    #
    # @!attribute [r] id
    #   @return [Integer] The unique identifier for the message.
    # @!attribute [r] messageable_id
    #   @return [Integer] The ID of the associated polymorphic message.
    # @!attribute [r] messageable_type
    #   @return [String] The type of the associated polymorphic message.
    # @!attribute status
    #   @return [String] The status of the message (see {STATUS}).
    # @!attribute [r] created_at
    #   @return [Time] The timestamp when the record was created.
    # @!attribute [r] updated_at
    #   @return [Time] The timestamp when the record was last updated.
    class Message < ::ActiveRecord::Base
      self.table_name = :outboxer_messages

      STATUS = {
        unpublished: "unpublished",
        publishing: "publishing",
        failed: "failed"
      }

      scope :unpublished, -> { where(status: STATUS[:unpublished]) }
      scope :publishing, -> { where(status: STATUS[:publishing]) }
      scope :failed, -> { where(status: STATUS[:failed]) }

      attribute :status, default: -> { STATUS[:unpublished] }

      belongs_to :messageable, polymorphic: true

      has_many :outboxer_exceptions,
               -> { order(created_at: :asc) },
               foreign_key: 'outboxer_message_id',
               class_name: "Outboxer::Models::Exception",
               dependent: :destroy
    end
  end
end
