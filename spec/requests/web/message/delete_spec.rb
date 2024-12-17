require 'spec_helper'

RSpec.describe 'POST /message/:id/delete', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'deletes a specific message and redirects' do
    message = Message.create!(status: 'queued', content: 'Delete Me')
    post "/message/#{message.id}/delete"
    follow_redirect!
    expect(last_response).to be_ok
    expect(Message.exists?(message.id)).to be_falsey
  end
end
