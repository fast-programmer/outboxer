
require 'spec_helper'

require_relative '../../../../app/models/application_record'
require_relative '../../../../app/models/event'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'POST /messages/delete_all', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let!(:event_1) { Event.create!(id: 1, type: 'Event') }
  let!(:event_2) { Event.create!(id: 2, type: 'Event') }

  context 'when no status provided' do
    before do
      header 'Host', 'localhost'
      post '/messages/delete_all', {
        page: 1,
        per_page: 10,
        sort: :queued_at,
        order: :desc,
        time_zone: 'Australia/Sydney'
      }
      follow_redirect!
    end

    it 'deletes all messages' do
      expect(Outboxer::Models::Message.count).to eq(0)
    end

    it 'does not delete events' do
      expect(Event.count).to eq(2)
    end

    it 'redirects to /messages' do
      expect(last_response).to be_ok
      expect(last_request.url).to include('messages')
      expect(last_request.url).to include('page=1')
      expect(last_request.url).to include('per_page=10')
      expect(last_request.url).to include('sort=queued_at')
      expect(last_request.url).to include('order=desc')
      expect(last_request.url).to include('time_zone=Australia%2FSydney')
    end

    it 'flashes deleted messages count' do
      expect(last_request.env['x-rack.flash'][:primary]).to include('2 messages have been deleted')
    end
  end

  context 'when queued status provided' do
    before do
      Outboxer::Models::Message.queued.last.update!(status: 'publishing')

      header 'Host', 'localhost'
      post '/messages/delete_all', {
        status: :queued,
        page: 1,
        per_page: 10,
        sort: :queued_at,
        order: :desc,
        time_zone: 'Australia/Sydney'
      }
      follow_redirect!
    end

    it 'deletes queued messages' do
      expect(Outboxer::Models::Message.queued.count).to eq(0)
    end

    it 'does not delete publishing messages' do
      expect(Outboxer::Models::Message.publishing.count).to eq(1)
    end

    it 'redirects to /messages' do
      expect(last_response).to be_ok
      expect(last_request.url).to include('messages')
      expect(last_request.url).to include('page=1')
      expect(last_request.url).to include('per_page=10')
      expect(last_request.url).to include('status=queued')
      expect(last_request.url).to include('sort=queued_at')
      expect(last_request.url).to include('order=desc')
      expect(last_request.url).to include('time_zone=Australia%2FSydney')
    end

    it 'flashes deleted messages count' do
      expect(last_request.env['x-rack.flash'][:primary]).to include('1 message have been deleted')
    end
  end
end
