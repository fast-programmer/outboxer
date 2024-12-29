module OutboxerIntegration
  module Test
    class StartedJob
      include Sidekiq::Job

      def perform(args)
        started_event = Test::StartedEvent.find(args['event_id'])

        Test::CompletedEvent.create!(
          body: {
            'test' => {
              'id' => started_event.body['test']['id'] } })
      end
    end
  end
end
