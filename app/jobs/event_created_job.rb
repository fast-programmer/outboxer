class EventCreatedJob
  include Sidekiq::Job

  def perform(args)
    event = Event.find(args['id'])

    puts "EventCreatedJob #{event.id}"
  end
end
