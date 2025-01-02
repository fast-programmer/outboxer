require 'spec_helper'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'POST /publisher/:id/delete', type: :request do
  include Rack::Test::Methods

  let(:event) { Event.create!(type: 'Event') }
  let(:message) { create(:outboxer_message, :queued, messageable: event) }
  let(:publisher) { create(:outboxer_publisher, :publishing, name: 'Test Publisher') }

  before do
    header 'Host', 'localhost'
    post "/publisher/#{publisher.id}/delete"
  end

  def app
    Outboxer::Web
  end

  it 'deletes publisher' do
    expect(Outboxer::Models::Publisher.exists?(publisher.id)).to be false
  end

  it 'redirects with flash' do
    follow_redirect!
    expect(last_response).to be_ok
    expect(last_request.env['x-rack.flash'][:primary]).to include('was deleted')
  end
end
