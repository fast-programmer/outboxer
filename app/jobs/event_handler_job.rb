class EventHandlerJob
  include Sidekiq::Job

  def self.perform_async(args)
    # handle event
  end
end

