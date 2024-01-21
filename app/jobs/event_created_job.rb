class EventCreatedJob
  include Sidekiq::Job

  def self.perform_async(args)
    event = Event.find(args['id'])

    puts "EventCreatedJob #{event.id}"
  end
end
