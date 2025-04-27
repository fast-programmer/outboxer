require "rails_helper"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /messages/delete_all", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let(:messageable_1) { double("Event", id: 1, class: double(name: "Event")) }
  let(:message_1_id) { Outboxer::Message.queue(messageable: messageable_1)[:id] }
  let!(:message_1) { Outboxer::Models::Message.find(message_1_id) }

  let(:messageable_2) { double("Event", id: 2, class: double(name: "Event")) }
  let(:message_2_id) { Outboxer::Message.queue(messageable: messageable_2)[:id] }
  let!(:message_2) { Outboxer::Models::Message.find(message_2_id) }

  let(:messageable_3) { double("Event", id: 3, class: double(name: "Event")) }
  let(:message_3_id) { Outboxer::Message.queue(messageable: messageable_3)[:id] }
  let!(:message_3) { Outboxer::Models::Message.find(message_3_id) }

  context "when no status provided" do
    before do
      header "Host", "localhost"

      post "/messages/delete_all", {
        page: 1,
        per_page: 10,
        sort: :queued_at,
        order: :desc,
        time_zone: "Australia/Sydney"
      }

      follow_redirect!
    end

    it "deletes all messages" do
      expect(Outboxer::Models::Message.count).to eq(0)
    end

    it "redirects to /messages" do
      expect(last_response).to be_ok
      expect(last_request.url).to include(
        "messages?sort=queued_at&order=desc&per_page=10&time_zone=Australia%2FSydney")
    end

    it "flashes deleted messages count" do
      expected_flash = URI.encode_www_form_component("success:Deleted 3 message")
      expect(last_request.url).to include("flash=#{expected_flash}")
    end
  end

  context "when failed status provided" do
    before do
      message_2.update!(status: Outboxer::Message::Status::PUBLISHING)
      message_3.update!(status: Outboxer::Message::Status::FAILED)

      header "Host", "localhost"

      post "/messages/delete_all", {
        status: :failed,
        page: 1,
        per_page: 10,
        sort: :queued_at,
        order: :desc,
        time_zone: "Australia/Sydney"
      }

      follow_redirect!
    end

    it "deletes failed messages" do
      expect(Outboxer::Models::Message.failed.count).to eq(0)
    end

    it "does not delete other messages" do
      expect(Outboxer::Models::Message.queued.count).to eq(1)
      expect(Outboxer::Models::Message.publishing.count).to eq(1)
    end

    it "redirects to /messages" do
      expect(last_response).to be_ok
      expect(last_request.url).to include(
        "messages?status=failed&sort=queued_at&order=desc&per_page=10&time_zone=Australia%2FSydney")
    end

    it "flashes deleted messages count" do
      expected_flash = URI.encode_www_form_component("success:Deleted 1 message")
      expect(last_request.url).to include("flash=#{expected_flash}")
    end
  end
end
