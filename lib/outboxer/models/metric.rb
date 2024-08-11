module Outboxer
  module Models
    class Metric < ActiveRecord::Base
      self.table_name = 'outboxer_metrics'

      validates :name, presence: true, uniqueness: true
      validates :value, presence: true
    end
  end
end
