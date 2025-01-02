require 'spec_helper'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'POST /message/:id/requeue', type: :request do
  include Rack::Test::Methods

  let(:message) { create(:outboxer_message, :failed) }

  before do
    header 'Host', 'localhost'
    post "/message/#{message.id}/requeue"
  end

  def app
    Outboxer::Web
  end

  it 'requeues a message' do
    message.reload
    expect(message.status).to eql('queued')
  end

  it 'redirects with flash' do
    follow_redirect!
    expect(last_response).to be_ok
    expect(last_request.env['x-rack.flash'][:primary]).to include('was queued')
  end
end
