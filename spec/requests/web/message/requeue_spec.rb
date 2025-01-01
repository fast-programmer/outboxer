require 'spec_helper'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'POST /message/:id/requeue', type: :request do
  include Rack::Test::Methods

  before do
    header 'Host', 'localhost'
  end

  def app
    Outboxer::Web
  end

  it 'requeues a message and redirects' do
    message = Outboxer::Models::Message.create!(
      status: 'queued',
      queued_at: Time.now,
      messageable_type: 'OutboxerIntegration::TestStartedEvent',
      messageable_id: '555')

    post "/message/#{message.id}/requeue"
    follow_redirect!
    expect(last_response).to be_ok
    expect(last_request.env['x-rack.flash'][:primary]).to include('was queued')
  end
end
