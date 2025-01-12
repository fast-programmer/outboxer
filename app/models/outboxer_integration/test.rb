module OutboxerIntegration
  class Test < ApplicationRecord
    self.table_name = "outboxer_integration_tests"

    def self.start
      transaction do
        test = create!

        event = TestStartedEvent.create!(
          eventable: test,
          body: {
            "test" => {
              "id" => test.id
            }
          })

        { id: test.id, events: [{ id: event.id, type: event.type }] }
      end
    end

    def self.complete(event_id:)
      transaction do
        started_event = TestStartedEvent.find(event_id)
        test = started_event.eventable
        test.touch

        event = TestCompletedEvent.create!(
          eventable: test,
          body: {
            "test" => {
              "id" => test.id
            }
          })

        { id: test.id, events: [{ id: event.id, type: event.type }] }
      end
    end

    has_many :events, as: :eventable
  end
end
