module OutboxerIntegration
  class Test < ActiveRecord::Base
    class CompletedEvent < ::Event
    end
  end
end
