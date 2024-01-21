require 'sidekiq'
require 'sidekiq/web'

require 'securerandom'

# File.open(".session.key", "w") {|f| f.write(SecureRandom.hex(32)) }

# use Rack::Session::Cookie, secret: File.read(".session.key"), same_site: true, max_age: 86400

use Rack::Session::Cookie, secret: SecureRandom.hex(32), same_site: true, max_age: 86400

run Sidekiq::Web
