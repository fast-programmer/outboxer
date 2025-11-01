require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".delete" do
      context "when the message status is failed" do
        let!(:message) { create(:outboxer_message, :failed) }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }
        let!(:historic_counter) { create(:outboxer_counter, :historic, failed_count: 20) }
        let!(:thread_counter) { create(:outboxer_counter, :thread, failed_count: 10) }

        let!(:result) { Message.delete(id: message.id, lock_version: message.lock_version) }

        it "deletes the message" do
          expect(Models::Message).not_to exist(message.id)
        end

        it "decrements the failed count thread counter metric" do
          thread_counter.reload

          expect(thread_counter.failed_count).to eq(9)
        end

        it "increments the total failed count metric" do
          expect(Counter.total[:failed_count]).to eq(29)
        end

        it "returns the message id" do
          expect(result[:id]).to eq(message.id)
        end
      end

      context "when the message status is published" do
        let!(:historic_counter) { create(:outboxer_counter, :historic, published_count: 20) }
        let!(:thread_counter) { create(:outboxer_counter, :thread, published_count: 10) }

        let!(:message) { create(:outboxer_message, :published) }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }

        let!(:result) { Message.delete(id: message.id, lock_version: message.lock_version) }

        it "deletes the message" do
          expect(Models::Message).not_to exist(message.id)
        end

        it "decrements the published count thread counter metric" do
          thread_counter.reload

          expect(thread_counter.published_count).to eq(9)
        end

        it "increments the total published count metric" do
          expect(Counter.total[:published_count]).to eq(29)
        end

        it "returns the message id" do
          expect(result[:id]).to eq(message.id)
        end
      end
    end
  end
end
