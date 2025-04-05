module Outboxer
  module Models
    class Signal < ::ActiveRecord::Base
      self.table_name = :outboxer_signals

      validates :name, presence: true, length: { maximum: 9 }

      validates :created_at, presence: true

      validates :publisher_id, presence: true
      belongs_to :publisher, foreign_key: "publisher_id"
    end
  end
end
