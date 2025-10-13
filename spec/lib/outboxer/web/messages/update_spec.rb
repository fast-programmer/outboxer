require "rails_helper"
require_relative "../../../../../lib/outboxer/web"

RSpec.describe "POST /messages/update", type: :request do
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

  before do
    message_2.update!(status: Outboxer::Message::Status::PUBLISHING)
    message_3.update!(status: Outboxer::Message::Status::FAILED)
    header "Host", "localhost"
  end

  context "when action is requeue_by_ids" do
    before do
      post "/messages/update", {
        selected_messages: [
          "#{message_2.id}:#{message_2.lock_version}",
          "#{message_3.id}:#{message_3.lock_version}"
        ],
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
      expect(Outboxer::Models::Message.queued.pluck(:id)).to match_array([
        message_1.id, message_2.id, message_3.id
      ])
    end

    it "redirects with flash message" do
      expect(last_response).to be_ok
      expect(last_request.url).to include(
        "messages?status=failed&sort=queued_at&order=desc&per_page=10&time_zone=Australia%2FSydney"
      )
      expected_flash = URI.encode_www_form_component("success:Requeued 2 messages")
      expect(last_request.url).to include("flash=#{expected_flash}")
    end
  end

  context "when action is delete_by_ids" do
    before do
      post "/messages/update", {
        selected_messages: [
          "#{message_2.id}:#{message_2.lock_version}",
          "#{message_3.id}:#{message_3.lock_version}"
        ],
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
        "messages?status=failed&sort=queued_at&order=desc&per_page=10&time_zone=Australia%2FSydney"
      )
      expected_flash = URI.encode_www_form_component("success:Deleted 2 messages")
      expect(last_request.url).to include("flash=#{expected_flash}")
    end
  end

  context "with invalid action" do
    before do
      post "/messages/update", {
        selected_messages: [
          "#{message_2.id}:#{message_2.lock_version}",
          "#{message_3.id}:#{message_3.lock_version}"
        ],
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
