require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".delete" do
      context "when the message status is failed" do
        let!(:message) { create(:outboxer_message, :failed) }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }
        let!(:historic_message_count) { create(:outboxer_message_count, :historic, failed: 20) }
        let!(:thread_message_count) { create(:outboxer_message_count, :thread, failed: 10) }

        let!(:result) { Message.delete(id: message.id, lock_version: message.lock_version) }

        it "deletes the message" do
          expect(Models::Message).not_to exist(message.id)
        end

        it "decrements the failed thread count metric" do
          thread_message_count.reload

          expect(thread_message_count.failed).to eq(9)
        end

        it "increments the total failed count metric" do
          expect(Message.metrics_by_status[:failed][:count]).to eq(29)
        end

        it "returns the message id" do
          expect(result[:id]).to eq(message.id)
        end
      end

      context "when the message status is published" do
        let!(:historic_message_count) { create(:outboxer_message_count, :historic, published: 20) }
        let!(:thread_message_count) { create(:outboxer_message_count, :thread, published: 10) }

        let!(:message) { create(:outboxer_message, :published) }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }

        let!(:result) { Message.delete(id: message.id, lock_version: message.lock_version) }

        it "deletes the message" do
          expect(Models::Message).not_to exist(message.id)
        end

        it "decrements the published count thread count metric" do
          thread_message_count.reload

          expect(thread_message_count.published).to eq(9)
        end

        it "increments the total published count metric" do
          expect(Message.metrics_by_status[:published][:count]).to eq(29)
        end

        it "returns the message id" do
          expect(result[:id]).to eq(message.id)
        end
      end
    end
  end
end
