require "rails_helper"

require_relative "../../../../../app/models/application_record"
require_relative "../../../../../app/models/event"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /publisher/:id/delete", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let(:event) { Event.create!(type: "Event") }
  let!(:message) do
    Outboxer::Message.find_by!(messageable_type: "Event", messageable_id: event.id)
  end
  let(:publisher) { create(:outboxer_publisher, :publishing, name: "Test Publisher") }

  before do
    header "Host", "localhost"
    post "/publisher/#{publisher.id}/delete"

    follow_redirect!
  end

  it "deletes publisher" do
    expect(Outboxer::Publisher.exists?(publisher.id)).to be false
  end

  it "displays flash" do
    expect(last_response).to be_ok
    expect(last_request.env["x-rack.flash"][:primary]).to include("was deleted")
  end
end
