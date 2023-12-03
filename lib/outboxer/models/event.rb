require "active_record"

module Outboxer
  module Models
    # Represents a event in the outbox.
    #
    # @!attribute [r] id
    #   @return [Integer] The unique identifier for the event.
    # @!attribute [r] outboxable_id
    #   @return [Integer] The ID of the associated polymorphic event.
    # @!attribute [r] outboxable_type
    #   @return [String] The type of the associated polymorphic event.
    # @!attribute status
    #   @return [String] The status of the event (see {STATUS}).
    # @!attribute [r] created_at
    #   @return [Time] The timestamp when the record was created.
    # @!attribute [r] updated_at
    #   @return [Time] The timestamp when the record was last updated.
    class Event < ::ActiveRecord::Base
      self.table_name = :outboxer_events

      STATUS = {
        unpublished: "unpublished",
        publishing: "publishing",
        failed: "failed"
      }

      attribute :status, default: -> { STATUS[:unpublished] }

      belongs_to :outboxer_eventable, polymorphic: true

      has_many :outboxer_exceptions,
               -> { order(created_at: :asc) },
               foreign_key: 'outboxer_event_id',
               class_name: "::Outboxer::Models::Exception",
               dependent: :destroy
    end
  end
end
