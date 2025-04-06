module Outboxer
  module Models
    class Setting < ActiveRecord::Base
      self.table_name = "outboxer_settings"

      # @!attribute [rw] name
      #   @return [String] The unique name of the setting.
      validates :name, presence: true

      # @!attribute [rw] value
      #   @return [String] The value associated with the setting name.
      validates :value, presence: true

      # @!attribute [rw] created_at
      #   @return [DateTime] The date and time when the setting was created.

      # @!attribute [rw] updated_at
      #   @return [DateTime] The date and time when the setting was updated.
    end
  end
end
