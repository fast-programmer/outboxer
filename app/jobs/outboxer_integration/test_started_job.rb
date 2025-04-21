module OutboxerIntegration
  class TestStartedJob
    include Sidekiq::Job

    def perform(event_id, event_type)
      test_started_event = event_type.safe_constantize.find(event_id)

      TestCompletedEvent.create!(body: { "test_id" => test_started_event.body["test_id"] })
    end
  end
end
