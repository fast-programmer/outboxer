module Outboxer
  module Models
    class Publisher < ::ActiveRecord::Base
      self.table_name = :outboxer_publishers

      validates :identifier, presence: true, length: { maximum: 279 }
      # 255 (hostname) + 1 (colon) + 10 (PID) + 1 (colon) + 12 (unique ID) = 279 characters

      module Status
        PUBLISHING = 'publishing'
        STOPPED = 'stopped'
        TERMINATING = 'terminating'
      end

      STATUSES = [
        Status::PUBLISHING,
        Status::STOPPED,
        Status::TERMINATING,
      ]

      scope :publishing, -> { where(status: Status::PUBLISHING) }
      scope :stopped, -> { where(status: Status::STOPPED) }
      scope :terminating, -> { where(status: Status::TERMINATING) }

      attribute :status, default: -> { Status::PUBLISHING }
      validates :status, inclusion: { in: STATUSES }, length: { maximum: 255 }

      has_many :signals,
        -> { order(created_at: :asc) },
        foreign_key: 'publisher_id',
        class_name: "Outboxer::Models::Signal",
        dependent: :destroy
    end
  end
end
