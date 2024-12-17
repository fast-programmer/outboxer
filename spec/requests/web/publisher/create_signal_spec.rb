require 'spec_helper'

RSpec.describe 'POST /publisher/:id/signals', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'sends a signal to a publisher and redirects' do
    publisher = Publisher.create!(name: 'Signal Receiver')
    post "/publisher/#{publisher.id}/signals", { name: 'restart' }
    follow_redirect!
    expect(last_response).to be_ok
    expect(flash[:primary]).to include('signalled')
  end
end
