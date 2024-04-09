class EventCreatedJob
  include Sidekiq::Job

  def perform(args)
    # Sidekiq.logger.info "EventCreatedJob#perform args: #{args.inspect}"
    # raise 'bad job'
    sleep 1.5
  end
end
