module Outboxer
  module Models
    class Publisher < ::ActiveRecord::Base
      self.table_name = :outboxer_publishers

      validates :name, presence: true

      module Status
        PUBLISHING = 'publishing'
        PAUSING = 'pausing'
        PAUSED = 'paused'
        RESUMING = 'resuming'
        TERMINATING = 'terminating'
      end

      STATUSES = [
        Status::PUBLISHING,
        Status::PAUSING,
        Status::PAUSED,
        Status::RESUMING,
        Status::TERMINATING,
      ]

      scope :publishing, -> { where(status: Status::PUBLISHING) }
      scope :pausing, -> { where(status: Status::PAUSING) }
      scope :paused, -> { where(status: Status::PAUSED) }
      scope :resuming, -> { where(status: Status::RESUMING) }
      scope :terminating, -> { where(status: Status::TERMINATING) }

      attribute :status, default: -> { Status::PUBLISHING }
      validates :status, inclusion: { in: STATUSES }, length: { maximum: 255 }
    end
  end
end
