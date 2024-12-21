module OutboxerIntegration
  module Message
    class PublishJob
      include Sidekiq::Job

      def perform(args)
        Sidekiq.logger.info "OutboxerIntegration::Message::PublishJob#perform: #{args.inspect}"
      end
    end
  end
end
