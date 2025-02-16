require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".requeue" do
      context "when failed message" do
        let!(:failed_message) { create(:outboxer_message, :failed) }

        let!(:queued_message) { Message.requeue(id: failed_message.id) }

        it "returns queued message" do
          expect(queued_message[:id]).to eq(failed_message.id)
        end

        it "updates failed message status to queued" do
          failed_message.reload

          expect(failed_message.status).to eq(Models::Message::Status::QUEUED)
        end
      end

      context "when queued messaged" do
        let(:queued_message) { create(:outboxer_message, :queued) }
        let!(:updated_at) { queued_message.updated_at }

        it "modifies updated_at" do
          Message.requeue(id: queued_message.id)

          queued_message.reload

          expect(queued_message.status).to eq(Models::Message::Status::QUEUED)
          expect(queued_message.updated_at).to be > updated_at
        end

        it "does not delete queued message" do
          begin
            Message.published(id: queued_message.id)
          rescue ArgumentError
            # ignore
          end

          expect(Models::Message.count).to eq(1)
          expect(Models::Message.first).to eq(queued_message)
        end
      end
    end
  end
end
