class Event < ApplicationRecord
  self.table_name = "events"

  default_scope { order(:index) }

  # associations

  belongs_to :eventable, polymorphic: true

  # validations

  validates :type, presence: true, length: { maximum: 255 }

  # callbacks

  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
