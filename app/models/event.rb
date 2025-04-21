class Event < ApplicationRecord
  self.table_name = "events"

  default_scope { order(:created_at) }

  # validations

  validates :type, presence: true, length: { maximum: 255 }

  # callbacks

  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
