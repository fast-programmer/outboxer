module OutboxerIntegration
  class Test < ApplicationRecord
    self.table_name = 'outboxer_integration_tests'

    def self.start(user_id: nil, tenant_id: nil)
      transaction do
        test = create!(tenant_id: tenant_id)

        event = TestStartedEvent.create!(
          user_id: user_id,
          tenant_id: tenant_id,
          eventable: test,
          body: {
            'test' => {
              'id' => test.id } })

        { id: test.id, events: [{ id: event.id, type: event.type }] }
      end
    end

    def self.complete(event_id:)
      transaction do
        started_event = TestStartedEvent.find(event_id)
        test = started_event.eventable
        test.touch

        event = TestCompletedEvent.create!(
          user_id: started_event.user_id,
          tenant_id: started_event.tenant_id,
          eventable: test,
          body: {
            'test' => {
              'id' => test.id } })

        { id: test.id, events: [{ id: event.id, type: event.type }] }
      end
    end

    has_many :events, as: :eventable
  end
end
