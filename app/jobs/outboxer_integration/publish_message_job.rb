module OutboxerIntegration
  class PublishMessageJob
    include Sidekiq::Job

    def perform(args)
      job_class_name = to_job_class_name(messageable_type: args["messageable_type"])
      job_class_name&.safe_constantize&.perform_async("event_id" => args["messageable_id"])
    end

    def to_job_class_name(messageable_type:)
      captures = messageable_type.match(/\A(?:(\w+)::)?(\w+)Event\z/)&.captures
      return if captures.nil?

      captures[0] ? "#{captures[0]}::#{captures[1]}Job" : "#{captures[1]}Job"
    end
  end
end
