require 'bundler/setup'

require 'outboxer'

logger = Outboxer::Logger.new($stdout, level: ::Logger::INFO)

Outboxer::Database.connect!(config: Outboxer::Database.config, logger: logger)

logger.info "[1] Before: #{ActiveRecord::Base.connection_pool.stat}"
ActiveRecord::Base.connection_pool.with_connection do
  message = Outboxer::Models::Message.last
  logger.info "[1] Message: #{message.id}"
end
logger.info "[1] After: #{ActiveRecord::Base.connection_pool.stat}"

logger.info "[2] Before: #{ActiveRecord::Base.connection_pool.stat}"
message = Outboxer::Models::Message.first
logger.info "[2] Message: #{message.id}"
logger.info "[2] After: #{ActiveRecord::Base.connection_pool.stat}"
