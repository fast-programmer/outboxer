module OutboxerIntegration
  module TestService
    module_function

    def start
      ActiveRecord::Base.transaction do
        test = Test.create!

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

    def complete(event_id:)
      ActiveRecord::Base.transaction do
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
  end
end
