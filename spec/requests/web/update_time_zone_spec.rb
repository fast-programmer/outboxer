require 'spec_helper'

require_relative "../../../lib/outboxer/web"

RSpec.describe 'POST /update_time_zone', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  before do
    header 'Host', 'localhost'
    post '/update_time_zone', { time_zone: 'Australia/Sydney' }
  end

  it 'redirects with updated time zone parameters' do
    follow_redirect!
    expect(last_response).to be_ok
    expect(last_request.url).to include('time_zone=Australia%2FSydney')
  end
end
