module OutboxerIntegration
  class TestStartedJob
    include Sidekiq::Job

    def perform(args)
      CompleteTestJob.perform_async({ "event_id" => args["event_id"] })
    end
  end
end
