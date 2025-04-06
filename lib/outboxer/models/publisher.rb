module Outboxer
  module Models
    class Publisher < ::ActiveRecord::Base
      self.table_name = :outboxer_publishers

      module Status
        PUBLISHING = "publishing"
        STOPPED = "stopped"
        TERMINATING = "terminating"
      end

      STATUSES = [
        Status::PUBLISHING,
        Status::STOPPED,
        Status::TERMINATING
      ]

      # @!attribute [rw] name
      #   @return [String] The unique name of the publisher
      #   which by default includes hostname and PID.
      validates :name, presence: true, length: { maximum: 263 }
      # 255 (hostname) + 1 (colon) + 7 (pid)

      # @!attribute [rw] status
      #   @return [String] The current status of the publisher.
      attribute :status, default: -> { Status::PUBLISHING }
      validates :status, inclusion: { in: STATUSES }, length: { maximum: 255 }

      # @!attribute [rw] settings
      #   @return [Hash] The settings for this publisher.

      # @!attribute [rw] metrics
      #   @return [Hash] The performance and operational metrics for this publisher.

      # @!attribute [rw] created_at
      #   @return [DateTime] The date and time when the publisher was created.

      # @!attribute [rw] updated_at
      #   @return [DateTime] The date and time when the publisher was updated.

      scope :publishing, -> { where(status: Status::PUBLISHING) }
      scope :stopped, -> { where(status: Status::STOPPED) }
      scope :terminating, -> { where(status: Status::TERMINATING) }

      # @!method messages
      #   @return [Outboxer::Models::Message::ActiveRecord_Associations_CollectionProxy]
      #   Returns all messages associated with this publisher.
      has_many :messages

      # @!method signals
      #   @return [Outboxer::Models::Signal::ActiveRecord_Associations_CollectionProxy]
      #   Returns all signals associated with this publisher.
      has_many :signals, foreign_key: "publisher_id", dependent: :destroy
    end
  end
end
