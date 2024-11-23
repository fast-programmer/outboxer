module Outboxer
  module Models
    class Message < ::ActiveRecord::Base
      self.table_name = :outboxer_messages

      belongs_to :publisher, class_name: "Outboxer::Models::Publisher"

      module Status
        QUEUED = 'queued'
        BUFFERED = 'buffered'
        PUBLISHING = 'publishing'
        PUBLISHED = 'published'
        FAILED = 'failed'
      end

      STATUSES = [
        Status::QUEUED,
        Status::BUFFERED,
        Status::PUBLISHING,
        Status::PUBLISHED,
        Status::FAILED
      ]

      scope :queued, -> { where(status: Status::QUEUED) }
      scope :buffered, -> { where(status: Status::BUFFERED) }
      scope :publishing, -> { where(status: Status::PUBLISHING) }
      scope :published, -> { where(status: Status::PUBLISHED) }
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
