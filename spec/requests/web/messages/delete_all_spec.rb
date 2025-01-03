
require 'spec_helper'

require_relative '../../../../app/models/application_record'
require_relative '../../../../app/models/event'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'GET /messages', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let!(:event) { Event.create!(id: 1, type: 'Event') }

  context 'when no status provided' do
    before do
      post '/messages/delete_all'
    end

    it 'deletes all messages' do
      expect(Outboxer::Models::Message.count).to eq(0)
      # expect(last_response.location).to include("/messages?")
      # follow_redirect!
      # expect(last_response.body).to include("0 messages have been deleted")
    end

    it 'redirects to /messages'

    it 'flashes deleted messages count'
  end

  context 'when queued status provided' do
    before do
      post '/messages/delete_all', { status: 'queued' }
    end

    it 'deletes messages with publishing status' do
      expect(Outboxer::Models::Message.count).to eq(1)
      # expect(last_response.location).to include("/messages?status=publishing")
      # follow_redirect!
      # expect(last_response.body).to include("1 message has been deleted")
    end

    it 'redirects to /messages'

    it 'flashes deleted messages count'
  end
end
