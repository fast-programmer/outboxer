require 'spec_helper'

require_relative "../../../../lib/outboxer/web"

RSpec.describe 'GET /', type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  context 'when there are no publishers' do
    before do
      header 'Host', 'localhost'

      get '/'
    end

    it "doesn't show any publishers" do
      expect(last_response).to be_ok
      expect(last_response.body).to include('There are no publishers to display')
    end
  end

  context 'when there is a publisher' do
    let!(:publisher) { create(:outboxer_publisher, :publishing, name: 'localhost:14325') }

    before do
      header 'Host', 'localhost'

      get '/'
    end

    it "shows publisher" do
      expect(last_response).to be_ok
      expect(last_response.body).to include(publisher.name)
    end
  end
end
