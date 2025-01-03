require 'spec_helper'

require_relative '../../../../app/models/application_record'
require_relative '../../../../app/models/event'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'POST /messages/update_per_page', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  context 'updating pagination settings' do
    it 'updates number of messages per page and redirects with full parameters' do
      post '/messages/update_per_page', {
        status: 'queued',
        sort: 'created_at',
        order: 'desc',
        page: 1,
        per_page: 10,
        time_zone: 'UTC'
      }
      follow_redirect!
      expect(last_response).to be_ok
      expect(last_request.url).to include('per_page=30')
      expect(last_request.url).to include('status=queued')
      expect(last_request.url).to include('sort=created_at')
      expect(last_request.url).to include('order=desc')
      expect(last_request.url).to include('page=2')
      expect(last_request.url).to include('time_zone=UTC')
    end
  end
end
