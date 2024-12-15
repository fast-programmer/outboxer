class Event < ActiveRecord::Base
  self.table_name = 'events'

  # validations

  # validates :user_id, presence: true
  # validates :tenant_id, presence: true
  # validates :created_at, presence: true

  # validates :type, presence: true

  # validates :eventable_id, presence: true
  # validates :eventable_type, presence: true

  # associations

  # belongs_to :eventable, polymorphic: true

  # callbacks

  after_create do |event|
    Outboxer::Message.queue(messageable: event)
  end
end
