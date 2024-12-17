require 'spec_helper'

require_relative "../../../lib/outboxer/web"

RSpec.describe 'GET /messages', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'displays messages with pagination' do
    get '/messages', { page: 1, per_page: 10 }
    expect(last_response).to be_ok
    expect(last_response.body).to include('Page 1')
    # Include checks for message content or pagination details
  end
end
