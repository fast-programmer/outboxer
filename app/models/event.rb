class Event < ActiveRecord::Base
  include Outboxer::Messageable

  self.inheritance_column = :_type_disabled

  attribute :created_at, :datetime, default: -> { Time.current }

  belongs_to :eventable, polymorphic: true

  validates :type, presence: true
  validates :eventable, presence: true

  has_outboxer_message dependent: :destroy
end
