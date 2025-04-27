require "rails_helper"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /publisher/:id/signals", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let(:publisher) { create(:outboxer_publisher, :publishing, name: "Test Publisher") }

  before do
    header "Host", "localhost"

    get "/publisher/#{publisher.id}"
  end

  it "returns publisher details" do
    expect(last_response).to be_ok
    expect(last_response.body).to include("Publisher/#{publisher.id}")
  end
end
