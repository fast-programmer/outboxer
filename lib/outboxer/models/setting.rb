module Outboxer
  module Models
    class Setting < ActiveRecord::Base
      self.table_name = 'outboxer_settings'

      validates :name, presence: true, uniqueness: true
      validates :value, presence: true
    end
  end
end
