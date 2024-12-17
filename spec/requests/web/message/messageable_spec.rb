require 'spec_helper'

RSpec.describe 'GET /message/:id/messageable', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'loads the associated messageable object for a message' do
    message = Message.create!(messageable_type: 'User', messageable_id: 1)
    get "/message/#{message.id}/messageable"
    expect(last_response).to be_ok
  end
end
