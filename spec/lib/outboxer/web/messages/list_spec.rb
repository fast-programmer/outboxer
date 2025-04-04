require "rails_helper"

require_relative "../../../../../app/models/application_record"
require_relative "../../../../../app/models/event"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "GET /messages", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  context "when no status provided" do
    let!(:event_1) { Event.create!(id: 1, type: "Event") }
    let!(:message_1) do
      Outboxer::Models::Message.find_by!(messageable_type: "Event", messageable_id: event_1.id)
    end

    let!(:event_2) { Event.create!(id: 2, type: "Event") }
    let!(:message_2) do
      Outboxer::Models::Message.find_by!(messageable_type: "Event", messageable_id: event_2.id)
    end

    before do
      header "Host", "localhost"

      get "/messages", { page: 1, per_page: 10 }
    end

    it "displays messages with pagination" do
      expect(last_response).to be_ok
      expect(last_response.body).to include("href=\"/message/#{message_1.id}?per_page=10\"")
      expect(last_response.body).to include("href=\"/message/#{message_2.id}?per_page=10\"")
    end
  end

  context "when publishing status provided" do
    let!(:event_1) { Event.create!(id: 1, type: "Event") }
    let!(:message_1) do
      Outboxer::Models::Message.find_by!(messageable_type: "Event", messageable_id: event_1.id)
    end

    let!(:event_2) { Event.create!(id: 2, type: "Event") }
    let!(:message_2) do
      Outboxer::Models::Message.find_by!(messageable_type: "Event", messageable_id: event_2.id)
    end

    before do
      message_2.update!(status: Outboxer::Message::Status::PUBLISHING)

      header "Host", "localhost"

      get "/messages", { page: 1, status: "publishing", per_page: 10 }
    end

    it "displays publishing message" do
      expect(last_response).to be_ok
      expect(last_response.body).not_to include("href=\"/message/#{message_1.id}?per_page=10\"")
      expect(last_response.body).to include(
        "href=\"/message/#{message_2.id}?status=publishing&per_page=10\"")
    end
  end
end
