require "rails_helper"

require_relative "../../../../../app/models/application_record"
require_relative "../../../../../app/models/event"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /message/:id/delete", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let!(:event) { Event.create!(id: 1, type: "Event") }
  let!(:message) do
    Outboxer::Message.find_by!(messageable_type: "Event", messageable_id: event.id)
  end

  before do
    header "Host", "localhost"

    post "/message/#{message.id}/delete"

    follow_redirect!
  end

  it "deletes message" do
    expect(Outboxer::Message.exists?(message.id)).to be false
  end

  it "redirects with flash" do
    expect(last_response).to be_ok
    expected_flash = URI.encode_www_form_component("success:Deleted message 1")
    expect(last_request.url).to include("flash=#{expected_flash}")
  end
end
