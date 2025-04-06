module Outboxer
  module Models
    class Signal < ::ActiveRecord::Base
      self.table_name = :outboxer_signals

      # @!attribute [rw] name
      #   @return [String] The name of the signal.
      validates :name, presence: true, length: { maximum: 9 }

      # @!attribute [rw] created_at
      #   @return [DateTime] The date and time when the signal was created.
      validates :created_at, presence: true

      # @!attribute [rw] publisher_id
      #   @return [Integer] The id of the publisher.

      # @!method publisher
      #   @return [Outboxer::Models::Publisher] The publisher that this signal was sent to.
      validates :publisher_id, presence: true
      belongs_to :publisher, foreign_key: "publisher_id"
    end
  end
end
