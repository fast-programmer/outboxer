module Event
  class CreatedJob
    include Sidekiq::Job

    def perform(args)
      Sidekiq.logger.info "Event::CreatedJob#perform args: #{args.inspect} started"

      Sidekiq.logger.info "Event::CreatedJob#perform args: #{args.inspect} finished"
    end
  end
end
