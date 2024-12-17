require 'spec_helper'

require_relative "../../../lib/outboxer/web"

RSpec.describe 'POST /update_time_zone', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'redirects with updated time zone parameters' do
    post '/update_time_zone', { time_zone: 'UTC' }
    follow_redirect!
    expect(last_response).to be_ok
    expect(last_request.url).to include('time_zone=UTC')
  end
end
