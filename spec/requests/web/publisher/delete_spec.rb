require 'spec_helper'

RSpec.describe 'POST /publisher/:id/delete', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'deletes a publisher and redirects' do
    publisher = Publisher.create!(name: 'Test Publisher')  # Create test data
    post "/publisher/#{publisher.id}/delete"
    follow_redirect!
    expect(last_response).to be_ok
    expect(Publisher.exists?(publisher.id)).to be_falsey  # Verify deletion
  end
end
