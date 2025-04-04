require "rails_helper"

require_relative "../../../../../app/models/application_record"
require_relative "../../../../../app/models/event"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /publisher/:id/signals", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let(:event) { Event.create!(type: "Event") }
  let!(:message) do
    Outboxer::Models::Message.find_by!(messageable_type: "Event", messageable_id: event.id)
  end
  let(:message) { create(:outboxer_message, :queued, messageable: event) }
  let(:publisher) { create(:outboxer_publisher, :publishing, name: "Test Publisher") }

  before do
    header "Host", "localhost"

    get "/publisher/#{publisher.id}"
  end

  it "returns publisher details" do
    expect(last_response).to be_ok
    expect(last_response.body).to include(message.id.to_s)
  end
end
