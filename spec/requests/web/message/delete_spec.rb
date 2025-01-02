require 'spec_helper'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'POST /message/:id/delete', type: :request do
  include Rack::Test::Methods

  let(:message) { create(:outboxer_message, :failed) }

  before do
    header 'Host', 'localhost'
    post "/message/#{message.id}/delete"
  end

  def app
    Outboxer::Web
  end

  it 'deletes message' do
    expect(Outboxer::Models::Message.exists?(message.id)).to be false
  end

  it 'redirects with flash' do
    follow_redirect!
    expect(last_response).to be_ok
    expect(last_request.env['x-rack.flash'][:primary]).to include('was deleted')
  end
end
