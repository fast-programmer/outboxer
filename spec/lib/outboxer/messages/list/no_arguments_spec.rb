require "spec_helper"

module Outboxer
  RSpec.describe Messages do
    describe ".list" do
      let(:publisher_1) { create(:outboxer_publisher, id: 41000, name: "server-01:41000") }
      let(:publisher_2) { create(:outboxer_publisher, id: 42000, name: "server-01:42000") }
      let(:publisher_3) { create(:outboxer_publisher, id: 43000, name: "server-01:43000") }
      let(:publisher_4) { create(:outboxer_publisher, id: 44000, name: "server-01:44000") }
      let(:publisher_5) { create(:outboxer_publisher, id: 45000, name: "server-01:45000") }

      let!(:message_1) do
        create(:outboxer_message, :queued,
          messageable_type: "Event",
          messageable_id: "1",
          updated_at: 5.minutes.ago,
          publisher_id: publisher_1.id,
          publisher_name: publisher_1.name)
      end

      let!(:message_2) do
        create(:outboxer_message, :failed,
          messageable_type: "Event",
          messageable_id: "2",
          updated_at: 4.minutes.ago,
          publisher_id: publisher_2.id,
          publisher_name: publisher_2.name)
      end

      let!(:message_3) do
        create(:outboxer_message, :buffered,
          messageable_type: "Event",
          messageable_id: "3",
          updated_at: 3.minutes.ago,
          publisher_id: publisher_3.id,
          publisher_name: publisher_3.name)
      end

      let!(:message_4) do
        create(:outboxer_message, :queued,
          messageable_type: "Event",
          messageable_id: "4",
          updated_at: 2.minutes.ago,
          publisher_id: publisher_4.id,
          publisher_name: publisher_4.name)
      end

      let!(:message_5) do
        create(:outboxer_message, :publishing,
          messageable_type: "Event",
          messageable_id: "5",
          updated_at: 1.minutes.ago,
          publisher_id: publisher_5.id,
          publisher_name: publisher_5.name)
      end

      context "when no arguments specified" do
        it "returns all messages" do
          expect(Messages.list).to eq({
            current_page: 1, limit_value: 100, total_count: 5, total_pages: 1,
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
                publisher_exists: true
              },
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
                publisher_exists: true
              },
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
                publisher_exists: true
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
                publisher_exists: true
              },
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
                publisher_exists: true
              }
            ]
          })
        end
      end
    end
  end
end
