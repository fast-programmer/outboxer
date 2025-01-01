require 'spec_helper'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'GET /publisher/:id', type: :request do
  include Rack::Test::Methods

  before do
    header 'Host', 'localhost'
  end

  def app
    Outboxer::Web
  end

  it 'displays a specific publisher' do
    publisher = Outboxer::Models::Publisher.create!(
      name: 'Test Publisher',
      settings: {},
      metrics: {})
    get "/publisher/#{publisher.id}"
    expect(last_response).to be_ok
  end
end
