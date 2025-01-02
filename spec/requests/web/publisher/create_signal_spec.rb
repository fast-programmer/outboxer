require 'spec_helper'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'POST /publisher/:id/signals', type: :request do
  include Rack::Test::Methods

  let(:event) { Event.create!(type: 'Event') }
  let(:message) { create(:outboxer_message, :queued, messageable: event) }
  let(:publisher) { create(:outboxer_publisher, :publishing, name: 'Test Publisher') }

  before do
    header 'Host', 'localhost'
    post "/publisher/#{publisher.id}/signals", { name: 'TSTP' }
  end

  def app
    Outboxer::Web
  end

  it 'creates signal' do
    expect(publisher.signals.first.name).to eql('TSTP')
  end

  it 'redirects with flash' do
    follow_redirect!
    expect(last_response).to be_ok
    expect(last_request.env['x-rack.flash'][:primary]).to include('signalled')
  end
end
