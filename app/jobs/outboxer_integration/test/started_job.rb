module OutboxerIntegration
  class Test
    class StartedJob
      include Sidekiq::Job

      def perform(args)
        ActiveRecord::Base.transaction do
          started_event = Test::StartedEvent.find(args['event_id'])

          test = Test.find(started_event.eventable_id)
          test.touch

          Test::CompletedEvent.create!(
            user_id: started_event.user_id,
            tenant_id: started_event.tenant_id,
            eventable: test,
            body: {
              'test' => {
                'id' => started_event.body['test']['id'] } })
        end
      end
    end
  end
end
