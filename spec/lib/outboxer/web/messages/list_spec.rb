require "rails_helper"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "GET /messages", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  context "when no status provided" do
    let(:messageable_1) { double("Event", id: 1, class: double(name: "Event")) }
    let(:message_1_id) { Outboxer::Message.queue(messageable: messageable_1)[:id] }
    let!(:message_1) { Outboxer::Models::Message.find(message_1_id) }

    let(:messageable_2) { double("Event", id: 2, class: double(name: "Event")) }
    let(:message_2_id) { Outboxer::Message.queue(messageable: messageable_2)[:id] }
    let!(:message_2) { Outboxer::Models::Message.find(message_2_id) }

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
    let(:messageable_1) { double("Event", id: 1, class: double(name: "Event")) }
    let(:message_1_id) { Outboxer::Message.queue(messageable: messageable_1)[:id] }
    let!(:message_1) { Outboxer::Models::Message.find(message_1_id) }

    let(:messageable_2) { double("Event", id: 2, class: double(name: "Event")) }
    let(:message_2_id) { Outboxer::Message.queue(messageable: messageable_2)[:id] }
    let!(:message_2) { Outboxer::Models::Message.find(message_2_id) }

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
