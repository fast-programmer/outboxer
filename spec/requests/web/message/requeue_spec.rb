require 'spec_helper'

require_relative "../../../lib/outboxer/web"

RSpec.describe 'POST /message/:id/requeue', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'requeues a message and redirects' do
    message = Message.create!(status: 'queued')  # Create test data
    post "/message/#{message.id}/requeue"
    follow_redirect!
    expect(last_response).to be_ok
    expect(flash[:primary]).to include('was queued')
  end
end
