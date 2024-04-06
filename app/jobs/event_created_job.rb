class EventCreatedJob
  include Sidekiq::Job

  def perform(args)
    Sidekiq.logger.info "EventCreatedJob#perform args: #{args.inspect}"
  end
end
