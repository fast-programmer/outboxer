require "active_support"

require_relative "outboxer/version"
require_relative "outboxer/railtie" if defined?(Rails)

require_relative "outboxer/models"

require_relative "outboxer/message"
require_relative "outboxer/messageable"

module Outboxer
end
