module OutboxerIntegration
  class Test < ActiveRecord::Base
    self.table_name = 'outboxer_integration_tests'

    has_many :events, as: :eventable
  end
end
