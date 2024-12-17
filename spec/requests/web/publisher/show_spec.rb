require 'spec_helper'

require_relative "../../../lib/outboxer/web"

RSpec.describe 'GET /publisher/:id', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'displays a specific publisher' do
    publisher = Publisher.create!(name: 'Test Publisher')  # Create test data
    get "/publisher/#{publisher.id}"
    expect(last_response).to be_ok
    # Include check for content related to the specific publisher
  end
end
