require "rails_helper"

require_relative "../../../../../app/models/application_record"
require_relative "../../../../../app/models/event"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /messages/delete_all", type: :request do
  include Rack::Test::Methods

  def app
    Outboxer::Web
  end

  let!(:event_1) { Event.create!(id: 1, type: "Event") }
  let!(:message_1) do
    Outboxer::Models::Message.find_by!(messageable_type: "Event", messageable_id: event_1.id)
  end

  let!(:event_2) { Event.create!(id: 2, type: "Event") }
  let!(:message_2) do
    Outboxer::Models::Message.find_by!(messageable_type: "Event", messageable_id: event_2.id)
  end

  let!(:event_3) { Event.create!(id: 3, type: "Event") }
  let!(:message_3) do
    Outboxer::Models::Message.find_by!(messageable_type: "Event", messageable_id: event_3.id)
  end

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

    it "does not delete events" do
      expect(Event.count).to eq(3)
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
