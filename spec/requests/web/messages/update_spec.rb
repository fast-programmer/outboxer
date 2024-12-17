require 'spec_helper'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'POST /messages/update', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'updates selected messages and redirects with query parameters' do
    ids = [1, 2]  # Assuming these IDs exist in your test setup
    post '/messages/update', { selected_ids: ids, action: 'requeue_by_ids' }
    follow_redirect!
    expect(last_response).to be_ok
    expect(flash[:primary]).to include('Requeued')
  end
end
