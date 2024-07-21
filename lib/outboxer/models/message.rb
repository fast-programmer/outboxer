module Outboxer
  module Models
    # Represents a message in the outbox.
    #
    # @!attribute [r] id
    #   @return [Integer] The unique id for the message.
    # @!attribute [r] messageable_id
    #   @return [Integer] The ID of the associated polymorphic message.
    # @!attribute [r] messageable_type
    #   @return [String] The type of the associated polymorphic message.
    # @!attribute status
    #   @return [String] The status of the message (see {STATUSES}).
    # @!attribute [r] created_at
    #   @return [Time] The timestamp when the record was created.
    # @!attribute [r] updated_at
    #   @return [Time] The timestamp when the record was last updated.
    class Message < ::ActiveRecord::Base
      self.table_name = :outboxer_messages

      module Status
        QUEUED = 'queued'
        DEQUEUED = 'dequeued'
        PUBLISHING = 'publishing'
        FAILED = 'failed'
      end

      STATUSES = [Status::QUEUED, Status::DEQUEUED, Status::PUBLISHING, Status::FAILED]

      scope :queued, -> { where(status: Status::QUEUED) }
      scope :dequeued, -> { where(status: Status::DEQUEUED) }
      scope :publishing, -> { where(status: Status::PUBLISHING) }
      scope :failed, -> { where(status: Status::FAILED) }

      attribute :status, default: -> { Status::QUEUED }
      validates :status, inclusion: { in: STATUSES }, length: { maximum: 255 }

      belongs_to :messageable, polymorphic: true

      has_many :exceptions,
        -> { order(created_at: :asc) },
        foreign_key: 'message_id',
        class_name: "Outboxer::Models::Exception",
        dependent: :destroy
    end
  end
end
