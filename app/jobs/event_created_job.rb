class EventCreatedJob
  include Sidekiq::Job

  def self.perform_async(args)
    # process created event
  end
end
