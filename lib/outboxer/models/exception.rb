require "active_record"

module Outboxer
  module Models
    # Represents an exception associated with an {Outboxer::Event}.
    #
    # @!attribute [r] id
    #   @return [Integer] The unique identifier for the exception.
    # @!attribute event_id
    #   @return [Integer] The ID of the associated {Outboxer::Event}.
    # @!attribute class_name
    #   @return [String] The class name of the exception.
    # @!attribute message_text
    #   @return [String] The exception's error message.
    # @!attribute backtrace
    #   @return [Array<String>] The exception's backtrace.
    # @!attribute [r] created_at
    #   @return [Time] The timestamp when the record was created.
    class Exception < ::ActiveRecord::Base
      self.table_name = :outboxer_exceptions

      belongs_to :outboxer_event, class_name: "::Outboxer::Models::Event"
    end
  end
end
