module OutboxerIntegration
  class TestStartedJob
    include Sidekiq::Job

    def perform(args)
      Test.complete(event_id: args['event_id'])
    end
  end
end
