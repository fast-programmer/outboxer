require "spec_helper"

module Outboxer
  RSpec.describe Messages do
    describe ".delete_all" do
      let!(:message_1) { create(:outboxer_message, :queued) }
      let!(:message_2) { create(:outboxer_message, :dequeued) }

      let!(:message_3) { create(:outboxer_message, :failed) }
      let!(:exception_1) { create(:outboxer_exception, message: message_3) }
      let!(:frame_1) { create(:outboxer_frame, exception: exception_1) }

      let!(:message_4) { create(:outboxer_message, :failed) }
      let!(:exception_2) { create(:outboxer_exception, message: message_4) }
      let!(:frame_2) { create(:outboxer_frame, exception: exception_2) }

      let!(:message_5) { create(:outboxer_message, :publishing) }

      context "when status is failed" do
        before do
          Messages.delete_all(status: Message::Status::FAILED, batch_size: 1)
        end

        it "deletes failed messages" do
          expect(Models::Message.pluck(:id))
            .to match_array([message_1.id, message_2.id, message_5.id])
        end
      end

      context "when status is dequeued" do
        before do
          Messages.delete_all(status: Message::Status::DEQUEUED, batch_size: 1)
        end

        it "deletes queued messages" do
          expect(Models::Message.all.pluck(:id))
            .to match_array([message_1.id, message_3.id, message_4.id, message_5.id])
        end
      end

      context "when status is publishing" do
        before do
          Messages.delete_all(status: Message::Status::PUBLISHING, batch_size: 1)
        end

        it "deletes publishing messages" do
          expect(Models::Message.pluck(:id))
            .to match_array([message_1.id, message_2.id, message_3.id, message_4.id])
        end
      end

      context "when status not passed" do
        before do
          Messages.delete_all(batch_size: 1)
        end

        it "deletes all messages" do
          expect(Models::Message.pluck(:id)).to be_empty
        end

        it "deletes all exceptions" do
          expect(Models::Exception.all).to be_empty
        end

        it "deletes all frames" do
          expect(Models::Frame.all).to be_empty
        end
      end

      context "when status is nil" do
        before do
          Messages.delete_all(status: nil, batch_size: 1)
        end

        it "deletes all messages" do
          expect(Models::Message.pluck(:id)).to be_empty
        end

        it "deletes all exceptions" do
          expect(Models::Exception.all).to be_empty
        end

        it "deletes all frames" do
          expect(Models::Frame.all).to be_empty
        end
      end
    end
  end
end
