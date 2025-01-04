require 'spec_helper'

require_relative '../../../../../app/models/application_record'
require_relative '../../../../../app/models/event'

require_relative "../../../../../lib/outboxer/web"

RSpec.describe 'GET /message/:id/messageable', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let(:event) { Event.create!(type: 'Event') }
  let!(:message) do
    Outboxer::Models::Message.find_by!(messageable_type: 'Event', messageable_id: event.id)
  end

  before do
    header 'Host', 'localhost'

    get "/message/#{message.id}/messageable"
  end

  it 'loads the associated messageable object for a message' do
    expect(last_response).to be_ok
  end
end
