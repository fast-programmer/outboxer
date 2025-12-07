require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".delete" do
      context "when the message status is failed" do
        let!(:message) { create(:outboxer_message, :failed) }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }
        let!(:historic_thread) do
          create(:outboxer_thread, :historic, failed_message_count: 20)
        end
        let!(:thread) do
          create(:outboxer_thread, :current, failed_message_count: 10)
        end

        let!(:result) { Message.delete(id: message.id, lock_version: message.lock_version) }

        it "deletes the message" do
          expect(Models::Message).not_to exist(message.id)
        end

        it "decrements the failed count thread count metric" do
          thread.reload

          expect(thread.failed_message_count).to eq(9)
        end

        it "increments the total failed count metric" do
          expect(Message.metrics_by_status[:failed][:count]).to eq(29)
        end

        it "returns the message id" do
          expect(result[:id]).to eq(message.id)
        end
      end

      context "when the message status is published" do
        let!(:historic_thread) do
          create(:outboxer_thread, :historic, published_message_count: 20)
        end
        let!(:thread) do
          create(:outboxer_thread, :current, published_message_count: 10)
        end

        let!(:message) { create(:outboxer_message, :published) }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }

        let!(:result) { Message.delete(id: message.id, lock_version: message.lock_version) }

        it "deletes the message" do
          expect(Models::Message).not_to exist(message.id)
        end

        it "decrements the published count thread count metric" do
          thread.reload

          expect(thread.published_message_count).to eq(9)
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
