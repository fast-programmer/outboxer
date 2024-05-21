require 'bundler/setup'

require 'dotenv/load'

require 'securerandom'
require 'sinatra'
require 'sidekiq'
require 'sidekiq/web'
require 'outboxer/web'

use Rack::Session::Cookie, secret: ENV['SESSION_SECRET'], same_site: true, max_age: 86400

map '/outboxer' do
  run Outboxer::Web
end

map '/sidekiq' do
  run Sidekiq::Web
end

# bundle exec rerun "rackup -p 3000"
