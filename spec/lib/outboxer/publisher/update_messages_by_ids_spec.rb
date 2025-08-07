require "rails_helper"

module Outboxer
  RSpec.describe Publisher do
    let(:publisher_id) { 1 }
    let(:publisher_name) { "test" }

    describe ".update_messages_by_ids" do
      context "when all messages are publishing" do
        let!(:message_to_mark_failed) { create(:outboxer_message, :publishing) }
        let!(:message_to_mark_published) { create(:outboxer_message, :publishing) }

        before do
          Publisher.update_messages_by_ids(
            publisher_id: publisher_id,
            publisher_name: publisher_name,
            published_message_ids: [message_to_mark_published.id],
            failed_message_ids: [message_to_mark_failed.id])
        end

        it "marks message published" do
          expect(Models::Message.published.pluck(:id)).to eq([message_to_mark_published.id])
        end

        it "marks message failed" do
          expect(Models::Message.failed.pluck(:id)).to eq([message_to_mark_failed.id])
        end
      end
    end
  end
end
