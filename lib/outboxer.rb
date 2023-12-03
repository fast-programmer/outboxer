require "active_support"

require_relative "outboxer/version"
require_relative "outboxer/railtie" if defined?(Rails)

require_relative "outboxer/models"

require_relative "outboxer/event"

module Outboxer
end
