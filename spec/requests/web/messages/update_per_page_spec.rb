require 'spec_helper'

require_relative "../../../lib/outboxer/web"

RSpec.describe 'POST /messages/update_per_page', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'updates number of messages per page and redirects' do
    post '/messages/update_per_page', { per_page: 50 }
    follow_redirect!
    expect(last_response).to be_ok
    expect(last_request.url).to include('per_page=50')
  end
end
