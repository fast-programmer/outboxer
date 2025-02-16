require "rails_helper"

module Outboxer
  RSpec.describe MessagesService do
    describe ".can_requeue?" do
      let!(:message_1) { create(:outboxer_message, :queued) }
      let!(:message_2) { create(:outboxer_message, :buffered) }
      let!(:message_3) { create(:outboxer_message, :failed) }
      let!(:message_4) { create(:outboxer_message, :failed) }
      let!(:message_5) { create(:outboxer_message, :publishing) }

      context "when status is queued" do
        it "returns true" do
          expect(MessagesService.can_requeue?(status: MessageService::Status::QUEUED)).to eq false
        end
      end

      context "when status is buffered" do
        it "returns true" do
          expect(MessagesService.can_requeue?(status: MessageService::Status::BUFFERED)).to eq true
        end
      end

      context "when status is publishing" do
        it "returns true" do
          expect(
            MessagesService.can_requeue?(status: MessageService::Status::PUBLISHING)).to eq true
        end
      end

      context "when status is failed" do
        it "returns true" do
          expect(
            MessagesService.can_requeue?(status: MessageService::Status::FAILED)).to eq true
        end
      end

      context "when status is nil" do
        it "returns false" do
          expect(MessagesService.can_requeue?(status: nil)).to eq false
        end
      end
    end
  end
end
