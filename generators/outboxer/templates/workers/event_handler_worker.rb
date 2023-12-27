class EventHandlerWorker
  include Sidekiq::Worker

  def perform(args)
    event = Event.find(args['id'])

    puts event.id
  end
end
