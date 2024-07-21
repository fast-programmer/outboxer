require "bundler/setup"
require "outboxer"
require "active_record"
require "sidekiq"

require_relative "../app/jobs/event/created_job"

environment = ENV["RAILS_ENV"] || "development"

db_config_content = File.read("config/database.yml")
db_config_erb_result = ERB.new(db_config_content).result
db_config = YAML.safe_load(db_config_erb_result)[environment]

ActiveRecord::Base.establish_connection(db_config.merge("pool" => 5))

redis_url = ENV["REDIS_URL"] || "redis://localhost:6379/0"

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
