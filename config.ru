require "bundler/setup"

require "dotenv/load"

require "securerandom"
require "sinatra"
require "sidekiq"
require "sidekiq/web"
require "outboxer/web"

use Rack::Session::Cookie,
  secret: ENV.fetch("SESSION_SECRET", nil), same_site: true, max_age: 86_400

map "/outboxer" do
  run Outboxer::Web
end

map "/sidekiq" do
  run Sidekiq::Web
end
