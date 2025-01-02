require 'spec_helper'

require_relative '../../../../app/models/application_record'
require_relative '../../../../app/models/event'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'GET /message/:id', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let(:event) { Event.create!(type: 'Event') }
  let(:message) { create(:outboxer_message, :queued, messageable: event) }

  before do
    header 'Host', 'localhost'
    get "/message/#{message.id}"
  end

  it 'loads message' do
    expect(last_response).to be_ok
    expect(last_response.body).to include(message.id.to_s)
  end
end
