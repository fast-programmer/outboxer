require 'rack/test'

require 'spec_helper'

require_relative "../../../lib/outboxer/web"

RSpec.describe 'GET /', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  it 'loads the home page' do
    header 'Host', 'localhost'

    get '/'

    expect(last_response).to be_ok
    expect(last_response.body).to include('There are no publishers to display')
  end
end
