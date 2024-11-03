module Outboxer
  module Models
    class Publisher < ::ActiveRecord::Base
      self.table_name = :outboxer_publishers

      has_many :signals, class_name: 'Outboxer::Models::Signal',
        foreign_key: 'publisher_id', dependent: :destroy

      validates :name, presence: true, length: { maximum: 263 }
      # 255 (hostname) + 1 (colon) + 7 (pid)

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
    end
  end
end
