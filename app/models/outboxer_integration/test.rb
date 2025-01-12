module OutboxerIntegration
  class Test < ApplicationRecord
    self.table_name = "outboxer_integration_tests"

    has_many :events, as: :eventable
  end
end
