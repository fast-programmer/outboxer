module OutboxerIntegration
  class TestStartedJob
    include Sidekiq::Job

    def perform(event_id)
      event = EventService.find_by_id(id: event_id)

      CompleteTestJob.perform_async({
        "user_id" => event.user_id,
        "tenant_id" => event.tenant_id,
        "id" => event.eventable_id,
        "lock_version" => event.index
      })
    end
  end
end
