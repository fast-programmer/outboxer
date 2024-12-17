require 'spec_helper'

RSpec.describe 'POST /messages/delete_all', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'deletes all messages older than a specific date' do
    post '/messages/delete_all', { status: 'archived' }
    follow_redirect!
    expect(last_response).to be_ok
    expect(flash[:primary]).to include('have been deleted')
  end
end
