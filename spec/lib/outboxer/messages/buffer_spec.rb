require "rails_helper"

module Outboxer
  RSpec.describe Messages do
    describe ".buffer" do
      context "when there are 2 queued messages" do
        let!(:queued_messages) do
          [
            create(:outboxer_message, :queued, updated_at: 2.minutes.ago),
            create(:outboxer_message, :queued, updated_at: 1.minute.ago)
          ]
        end

        context "when limit is 1" do
          let!(:buffered_messages) { Messages.buffer(limit: 1) }

          it "returns first buffered message" do
            expect(buffered_messages.count).to eq(1)

            buffered_message = buffered_messages.first
            expect(buffered_message[:id]).to eq(queued_messages[0].id)
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
