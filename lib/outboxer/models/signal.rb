module Outboxer
  module Models
    class Signal < ::ActiveRecord::Base
      self.table_name = :outboxer_signals

      validates :name, presence: true, length: { maximum: 9 }

      belongs_to :publisher, class_name: 'Outboxer::Models::Publisher', foreign_key: 'publisher_id'
      validates :publisher_id, presence: true
    end
  end
end