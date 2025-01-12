module OutboxerIntegration
  class CompleteTestJob
    include Sidekiq::Job

    def perform(args)
      Test.complete(event_id: args["event_id"])
    end
  end
end
