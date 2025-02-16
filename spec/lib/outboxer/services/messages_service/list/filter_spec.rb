require "rails_helper"

module Outboxer
  RSpec.describe MessagesService do
    let!(:message_1) do
      create(:outboxer_message, :queued,
        messageable_type: "Event", messageable_id: "1",
        updated_at: 10.seconds.ago,
        publisher_id: 41_000,
        publisher_name: "server-01:41000")
    end

    let!(:message_2) do
      create(:outboxer_message, :failed,
        messageable_type: "Event", messageable_id: "2",
        updated_at: 9.seconds.ago,
        publisher_id: 42_000,
        publisher_name: "server-02:42000")
    end

    let!(:message_3) do
      create(:outboxer_message, :buffered,
        messageable_type: "Event", messageable_id: "3",
        updated_at: 8.seconds.ago,
        publisher_id: 43_000,
        publisher_name: "server-03:43000")
    end

    let!(:message_4) do
      create(:outboxer_message, :queued,
        messageable_type: "Event", messageable_id: "4",
        updated_at: 7.seconds.ago,
        publisher_id: 44_000,
        publisher_name: "server-04:44000")
    end

    let!(:message_5) do
      create(:outboxer_message, :publishing,
        messageable_type: "Event", messageable_id: "5",
        updated_at: 6.seconds.ago,
        publisher_id: 45_000,
        publisher_name: "server-05:45000")
    end

    describe ".list" do
      context "when an invalid status is specified" do
        it "raises an ArgumentError" do
          expect do
            MessagesService.list(status: :invalid)
          end.to raise_error(
            ArgumentError, "status must be #{MessagesService::LIST_STATUS_OPTIONS.join(" ")}")
        end
      end

      context "with queued status" do
        it "returns queued messages" do
          expect(MessagesService.list(status: :queued)).to eq({
            current_page: 1, limit_value: 100, total_count: 2, total_pages: 1,
            messages: [
              {
                id: message_1.id,
                status: message_1.status.to_sym,
                messageable_type: message_1.messageable_type,
                messageable_id: message_1.messageable_id,
                queued_at: message_1.queued_at,
                buffered_at: message_1.buffered_at,
                publishing_at: message_1.publishing_at,
                updated_at: message_1.updated_at,
                publisher_id: message_1.publisher_id,
                publisher_name: message_1.publisher_name,
                publisher_exists: false
              },
              {
                id: message_4.id,
                status: message_4.status.to_sym,
                messageable_type: message_4.messageable_type,
                messageable_id: message_4.messageable_id,
                queued_at: message_4.queued_at,
                buffered_at: message_4.buffered_at,
                publishing_at: message_4.publishing_at,
                updated_at: message_4.updated_at,
                publisher_id: message_4.publisher_id,
                publisher_name: message_4.publisher_name,
                publisher_exists: false
              }
            ]
          })
        end
      end

      context "with buffered status" do
        it "returns buffered messages" do
          expect(MessagesService.list(status: :buffered)).to eq({
            current_page: 1, limit_value: 100, total_count: 1, total_pages: 1,
            messages: [
              {
                id: message_3.id,
                status: message_3.status.to_sym,
                messageable_type: message_3.messageable_type,
                messageable_id: message_3.messageable_id,
                queued_at: message_3.queued_at,
                buffered_at: message_3.buffered_at,
                publishing_at: message_3.publishing_at,
                updated_at: message_3.updated_at,
                publisher_id: message_3.publisher_id,
                publisher_name: message_3.publisher_name,
                publisher_exists: false
              }
            ]
          })
        end
      end

      context "with publishing status" do
        it "returns publishing messages" do
          expect(MessagesService.list(status: :publishing)).to eq({
            current_page: 1, limit_value: 100, total_count: 1, total_pages: 1,
            messages: [
              {
                id: message_5.id,
                status: message_5.status.to_sym,
                messageable_type: message_5.messageable_type,
                messageable_id: message_5.messageable_id,
                queued_at: message_5.queued_at,
                buffered_at: message_5.buffered_at,
                publishing_at: message_5.publishing_at,
                updated_at: message_5.updated_at,
                publisher_id: message_5.publisher_id,
                publisher_name: message_5.publisher_name,
                publisher_exists: false
              }
            ]
          })
        end
      end

      context "with failed status" do
        it "returns failed messages" do
          expect(MessagesService.list(status: :failed)).to eq({
            current_page: 1, limit_value: 100, total_count: 1, total_pages: 1,
            messages: [
              {
                id: message_2.id,
                status: message_2.status.to_sym,
                messageable_type: message_2.messageable_type,
                messageable_id: message_2.messageable_id,
                queued_at: message_2.queued_at,
                buffered_at: message_2.buffered_at,
                publishing_at: message_2.publishing_at,
                updated_at: message_2.updated_at,
                publisher_id: message_2.publisher_id,
                publisher_name: message_2.publisher_name,
                publisher_exists: false
              }
            ]
          })
        end
      end
    end
  end
end
