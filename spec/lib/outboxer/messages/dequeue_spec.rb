require "spec_helper"

module Outboxer
  RSpec.describe Messages do
    describe ".dequeue" do
      context "when there are 2 queued messages" do
        let!(:queued_messages) do
          [
            create(:outboxer_message, :queued, updated_at: 2.minutes.ago),
            create(:outboxer_message, :queued, updated_at: 1.minute.ago)
          ]
        end

        context "when limit is 1" do
          let!(:dequeued_messages) { Messages.dequeue(limit: 1) }

          it "returns first dequeued message" do
            expect(dequeued_messages.count).to eq(1)

            dequeued_message = dequeued_messages.first
            expect(dequeued_message[:id]).to eq(queued_messages[0].id)
          end

          it "keeps last queued message" do
            remaining_messages = Models::Message.where(status: Models::Message::Status::QUEUED)

            expect(remaining_messages.count).to eq(1)

            remaining_message = remaining_messages.last
            expect(remaining_message).to eq(queued_messages.last)
          end
        end
      end
    end
  end
end
