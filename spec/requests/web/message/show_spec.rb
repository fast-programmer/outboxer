require 'spec_helper'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'GET /message/:id', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'loads a specific message details' do
    # message = Outboxer::Models::Message.create!(...)

    get "/message/#{message.id}"
    expect(last_response).to be_ok
    expect(last_response.body).to include('Test Message')
  end
end
