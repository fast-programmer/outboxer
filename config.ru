require "bundler/setup"

require "dotenv/load"

require "securerandom"
require "sinatra"
require "sidekiq"
require "sidekiq/web"
require "outboxer/web"

require_relative "app/models/application_record"
require_relative "app/models/event"

use Rack::Session::Cookie, secret: ENV["SESSION_SECRET"], same_site: true, max_age: 86_400

map "/outboxer" do
  run Outboxer::Web
end

map "/sidekiq" do
  run Sidekiq::Web
end
