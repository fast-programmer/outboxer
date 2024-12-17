require 'spec_helper'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'POST /messages/requeue_all', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'queues all messages and redirects' do
    post '/messages/requeue_all', { status: 'buffered' }

    follow_redirect!
    expect(last_response).to be_ok
    expect(flash[:primary]).to include('have been queued')
  end
end
