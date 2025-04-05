require "rails_helper"

require_relative "../../../../../app/models/application_record"
require_relative "../../../../../app/models/event"

require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /messages/update", type: :request do
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

  before do
    message_2.update!(status: Outboxer::Message::Status::PUBLISHING)
    message_3.update!(status: Outboxer::Message::Status::FAILED)

    header "Host", "localhost"
  end

  context "when action is requeue_by_ids" do
    let(:ids) { [message_2.id, message_3.id] }

    before do
      post "/messages/update", {
        selected_ids: ids,
        action: "requeue_by_ids",
        status: :failed,
        page: 1,
        per_page: 10,
        sort: :queued_at,
        order: :desc,
        time_zone: "Australia/Sydney"
      }

      follow_redirect!
    end

    it "queues selected messages" do
      expect(Outboxer::Models::Message.queued.pluck(:id)).to eq([
        message_1.id, message_2.id, message_3.id
      ])
    end

    it "redirects with flash message" do
      expect(last_response).to be_ok
      expect(last_request.url).to include(
        "messages?status=failed&sort=queued_at&order=desc&per_page=10&time_zone=Australia%2FSydney")

      expected_flash = URI.encode_www_form_component("success:Requeued 2 messages")
      expect(last_request.url).to include("flash=#{expected_flash}")
    end
  end

  context "when action is delete_by_ids" do
    let(:ids) { [message_2.id, message_3.id] }

    before do
      post "/messages/update", {
        selected_ids: ids,
        action: "delete_by_ids",
        status: :failed,
        page: 1,
        per_page: 10,
        sort: :queued_at,
        order: :desc,
        time_zone: "Australia/Sydney"
      }

      follow_redirect!
    end

    it "deletes selected messages" do
      expect(Outboxer::Models::Message.all.pluck(:id)).to eq([message_1.id])
    end

    it "redirects with flash message" do
      expect(last_response).to be_ok
      expect(last_request.url).to include(
        "messages?status=failed&sort=queued_at&order=desc&per_page=10&time_zone=Australia%2FSydney")
      expected_flash = URI.encode_www_form_component("success:Deleted 2 messages")
      expect(last_request.url).to include("flash=#{expected_flash}")
    end
  end

  context "with invalid action" do
    let(:ids) { [message_2.id, message_3.id] }

    before do
      post "/messages/update", {
        selected_ids: ids,
        action: "invalid",
        status: :failed,
        page: 1,
        per_page: 10,
        sort: :queued_at,
        order: :desc,
        time_zone: "Australia/Sydney"
      }
    end

    it "responds with 500 internal server error" do
      expect(last_response.status).to eq(500)
    end
  end
end
