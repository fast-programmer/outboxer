require "active_record"

module Outboxer
  module Models
    # Represents a message in the outbox.
    #
    # @!attribute [r] id
    #   @return [Integer] The unique identifier for the message.
    # @!attribute [r] outboxable_id
    #   @return [Integer] The ID of the associated polymorphic message.
    # @!attribute [r] outboxable_type
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
        PUBLISHED = 'published'
        FAILED = 'failed'
      end

      STATUSES = [Status::UNPUBLISHED, Status::PUBLISHING, Status::PUBLISHED, Status::FAILED]

      scope :unpublished, -> { where(status: Status::UNPUBLISHED) }
      scope :publishing, -> { where(status: Status::PUBLISHING) }
      scope :failed, -> { where(status: Status::FAILED) }

      attribute :status, default: -> { Status::UNPUBLISHED }
      validates :status, inclusion: { in: STATUSES }, length: { maximum: 255 }

      belongs_to :outboxable, polymorphic: true

      has_many :exceptions,
        -> { order(created_at: :asc) },
        foreign_key: 'message_id',
        class_name: "Outboxer::Models::Exception",
        dependent: :destroy
    end
  end
end
