module Outboxer
  module Models
    class Message < ::ActiveRecord::Base
      self.table_name = :outboxer_messages

      module Status
        QUEUED = "queued"
        BUFFERED = "buffered"
        PUBLISHING = "publishing"
        PUBLISHED = "published"
        FAILED = "failed"
      end

      STATUSES = [
        Status::QUEUED,
        Status::BUFFERED,
        Status::PUBLISHING,
        Status::PUBLISHED,
        Status::FAILED
      ]

      # @!attribute [rw] status
      #   @return [String] Current status of the message, defaults to `queued`.
      attribute :status, default: -> { Status::QUEUED }

      # @!attribute [rw] messageable_id
      #   @return [String] the polymorphic model id.

      # @!attribute [rw] messageable_type
      #   @return [String] the polymorphic model type.

      # @!attribute [rw] queued_at
      #   @return [DateTime] The date and time when the message was queued.

      # @!attribute [rw] buffered_at
      #   @return [DateTime] The date and time when the message was buffered.

      # @!attribute [rw] publishing_at
      #   @return [DateTime] The date and time when the message began publishing.

      # @!attribute [rw] updated_at
      #   @return [DateTime] The date and time when the message was last updated.

      # @!attribute [rw] publisher_id
      #   @return [Integer] The id of the publisher that last updated this message.

      # @!attribute [rw] publisher_name
      #   @return [String] The name of the publisher that last updated this message.

      validates :status, inclusion: { in: STATUSES }, length: { maximum: 255 }

      scope :queued, -> { where(status: Status::QUEUED) }
      scope :buffered, -> { where(status: Status::BUFFERED) }
      scope :publishing, -> { where(status: Status::PUBLISHING) }
      scope :published, -> { where(status: Status::PUBLISHED) }
      scope :failed, -> { where(status: Status::FAILED) }

      # @!method messageable
      #   @return [ActiveRecord::Base] Polymorphic association to an event like model.
      belongs_to :messageable, polymorphic: true

      # @!method exceptions
      #   @return [ActiveRecord::Associations::CollectionProxy<Outboxer::Models::Exception>]
      #     Ordered list of exceptions raised during the processing of this message.
      has_many :exceptions, -> { order(created_at: :asc) },
        foreign_key: "message_id", dependent: :destroy

      # @!method publisher
      #   @return [Outboxer::Models::Publisher] The publisher that last updated this message.
      belongs_to :publisher
    end
  end
end
