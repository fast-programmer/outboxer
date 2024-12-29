module OutboxerIntegration
  class Test < ActiveRecord::Base
    class StartedEvent < ::Event
    end
  end
end
