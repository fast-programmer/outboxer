module OutboxerIntegration
  module Message
    class PublishJob
      include Sidekiq::Job

      MESSAGEABLE_TYPE_REGEX = /\A([A-Za-z]+)::([A-Za-z]+)::([A-Za-z]+)Event\z/

      def perform(args)
        captures = args['messageable_type'].match(MESSAGEABLE_TYPE_REGEX)&.captures
        return if captures.nil?

        begin
          "#{captures[0]}::#{captures[1]}::#{captures[2]}Job".constantize
            .perform_async('event_id' => args['messageable_id'])
        rescue NameError
          # no-op if constant not defined
        end
      end
    end
  end
end
