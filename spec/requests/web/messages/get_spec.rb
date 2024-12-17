require 'spec_helper'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'GET /messages', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'loads the messages page with parameters' do
    get '/messages', { status: 'active', page: 1 }

    expect(last_response).to be_ok
    expect(last_response.body).to include('active')
  end
end
