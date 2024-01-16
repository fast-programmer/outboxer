class Invoice < ActiveRecord::Base
  has_many :events,
    -> { order(created_at: :asc) },
    as: :eventable
end
