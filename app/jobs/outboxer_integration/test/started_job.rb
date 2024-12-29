module OutboxerIntegration
  class Test
    class StartedJob
      include Sidekiq::Job

      def perform(args)
        Test.complete(event_id: args['event_id'])
      end
    end
  end
end
