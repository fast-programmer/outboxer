require 'bundler/setup'

require 'securerandom'
require 'sinatra'
require 'sidekiq'
require 'sidekiq/web'
require 'outboxer/web'

use Rack::Session::Cookie, secret: SecureRandom.hex(32), same_site: true, max_age: 86400

map '/outboxer' do
  run Outboxer::Web
end

map '/sidekiq' do
  run Sidekiq::Web
end

# bundle exec rackup -p 3000
