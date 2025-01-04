require 'spec_helper'

require_relative '../../../../../app/models/application_record'
require_relative '../../../../../app/models/event'

require_relative "../../../../../lib/outboxer/web"

RSpec.describe 'POST /messages/requeue_all', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let!(:event_1) { Event.create!(id: 1, type: 'Event') }
  let!(:message_1) do
    Outboxer::Models::Message.find_by!(messageable_type: 'Event', messageable_id: event_1)
  end

  let!(:event_2) { Event.create!(id: 2, type: 'Event') }
  let!(:message_2) do
    Outboxer::Models::Message.find_by!(messageable_type: 'Event', messageable_id: event_2)
  end

  let!(:event_3) { Event.create!(id: 3, type: 'Event') }
  let!(:message_3) do
    Outboxer::Models::Message.find_by!(messageable_type: 'Event', messageable_id: event_3)
  end

  context 'when no status provided' do
    before do
      message_2.update!(status: Outboxer::Models::Message::Status::PUBLISHING)
      message_3.update!(status: Outboxer::Models::Message::Status::FAILED)

      header 'Host', 'localhost'

      post '/messages/requeue_all', {
        page: 1,
        per_page: 10,
        sort: :queued_at,
        order: :desc,
        time_zone: 'Australia/Sydney'
      }
    end

    it 'responds with 500 internal server error' do
      expect(last_response.status).to eq(500)
    end

    it 'does not requeue messages' do
      expect(Outboxer::Models::Message.queued.count).to eq(1)
      expect(Outboxer::Models::Message.publishing.count).to eq(1)
      expect(Outboxer::Models::Message.failed.count).to eq(1)
    end
  end

  context 'when failed status provided' do
    before do
      message_2.update!(status: Outboxer::Models::Message::Status::PUBLISHING)
      message_3.update!(status: Outboxer::Models::Message::Status::FAILED)

      header 'Host', 'localhost'

      post '/messages/requeue_all', {
        status: :failed,
        page: 1,
        per_page: 10,
        sort: :queued_at,
        order: :desc,
        time_zone: 'Australia/Sydney'
      }

      follow_redirect!
    end

    it 'requeues messages' do
      expect(Outboxer::Models::Message.queued.count).to eq(2)
    end

    it 'does not requeue publishing messages' do
      expect(Outboxer::Models::Message.publishing.count).to eq(1)
    end

    it 'redirects to /messages' do
      expect(last_response).to be_ok
      expect(last_request.url).to include(
        "messages?status=failed&sort=queued_at&order=desc&per_page=10&time_zone=Australia%2FSydney")
    end

    it 'flashes requeued messages count' do
      expect(last_request.env['x-rack.flash'][:primary]).to include('1 message have been queued')
    end
  end
end
