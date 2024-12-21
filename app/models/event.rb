class Event < ActiveRecord::Base
  self.table_name = 'events'

  # validations

  validates :type, presence: true, length: { maximum: 255 }

  # callbacks

  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
