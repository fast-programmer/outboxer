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

      UNPUBLISHED = 'unpublished'
      PUBLISHING = 'publishing'
      PUBLISHED = 'published'
      FAILED = 'failed'

      STATUSES = [UNPUBLISHED, PUBLISHING, PUBLISHED, FAILED]

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

      def self.ransackable_attributes(auth_object = nil)
        ["created_at", "id", "id_value", "messageable_id", "messageable_type", "status", "updated_at"]
      end

      def self.ransackable_associations(auth_object = nil)
        ["messageable", "outboxer_exceptions"]
      end
    end
  end
end
