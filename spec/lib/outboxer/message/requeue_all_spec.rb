require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".requeue_all" do
      let!(:message_1) { create(:outboxer_message, :queued) }
      let!(:message_2) { create(:outboxer_message, :buffered) }
      let!(:message_3) { create(:outboxer_message, :failed) }
      let!(:message_4) { create(:outboxer_message, :failed) }
      let!(:message_5) { create(:outboxer_message, :publishing) }

      context "when status is failed" do
        before do
          Message.requeue_all(status: Message::Status::FAILED, batch_size: 1)
        end

        it "sets failed messages to queued" do
          expect(
            Models::Message.where(status: Message::Status::QUEUED).pluck(:id))
            .to match_array([message_1.id, message_3.id, message_4.id])
        end
      end

      context "when status is buffered" do
        before do
          Message.requeue_all(status: Message::Status::BUFFERED, batch_size: 1)
        end

        it "sets queued messages to queued" do
          expect(
            Models::Message.where(status: Message::Status::QUEUED).pluck(:id))
            .to match_array([message_1.id, message_2.id])
        end
      end

      context "when status is publishing" do
        before do
          Message.requeue_all(status: Message::Status::PUBLISHING, batch_size: 1)
        end

        it "sets publishing messages to queued" do
          expect(
            Models::Message.where(status: Message::Status::QUEUED).pluck(:id))
            .to match_array([message_1.id, message_5.id])
        end
      end

      context "when status is nil" do
        it "raises ArgumentError with message" do
          expect do
            Message.requeue_all(status: nil, batch_size: 1)
          end.to raise_error(
            ArgumentError, "Status nil must be one of buffered, publishing, failed")
        end
      end
    end
  end
end
