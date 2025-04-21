module OutboxerIntegration
  class TestStartedJob
    include Sidekiq::Job

    def perform(event_id)
      test_started_event = TestStartedEvent.find(event_id)

      TestCompletedEvent.create!(body: { "test_id" => test_started_event.body["test_id"] })
    end
  end
end
