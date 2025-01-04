require "bundler/setup"
require "active_record"
require "sidekiq"

require "outboxer"

Dir[File.expand_path("../app/models/**/*.rb", __dir__)].each { |file| require file }
Dir[File.expand_path("../app/jobs/**/*.rb", __dir__)].each { |file| require file }

environment = ENV["RAILS_ENV"] || "development"

db_config_content = File.read("config/database.yml")
db_config_erb_result = ERB.new(db_config_content).result
db_config = YAML.load(db_config_erb_result)[environment]

ActiveRecord::Base.establish_connection(db_config.merge("pool" => 5))

redis_url = ENV["REDIS_URL"] || "redis://localhost:6379/0"

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
