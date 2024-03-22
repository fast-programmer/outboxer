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

      module Status
        UNPUBLISHED = 'unpublished'
        PUBLISHING = 'publishing'
        FAILED = 'failed'
      end

      STATUSES = [Status::UNPUBLISHED, Status::PUBLISHING, Status::FAILED]

      scope :unpublished, -> { where(status: Status::UNPUBLISHED) }
      scope :publishing, -> { where(status: Status::PUBLISHING) }
      scope :failed, -> { where(status: Status::FAILED) }

      attribute :status, default: -> { Status::UNPUBLISHED }
      validates :status, inclusion: { in: STATUSES }, length: { maximum: 255 }

      belongs_to :messageable, polymorphic: true

      has_many :exceptions,
               -> { order(created_at: :asc) },
               foreign_key: 'message_id',
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
