require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".delete" do
      context "when the message status is failed" do
        before do
          Models::MessageTotal.create!(status: "failed", partition: 1, value: 20)
          Models::MessageCount.create!(status: "failed", partition: 1, value: 10)
        end

        let!(:message) { create(:outboxer_message, :failed) }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }

        let!(:result) { Message.delete(id: message.id) }

        it "deletes the message" do
          expect(Models::Message).not_to exist(message.id)
        end

        it "decrements the count failed metric" do
          expect(Message.count_by_status["failed"]).to eq(9)
        end

        it "increments the total failed metric" do
          expect(Message.total_by_status["failed"]).to eq(20)
        end

        it "returns the message id" do
          expect(result[:id]).to eq(message.id)
        end
      end

      context "when the message status is published" do
        before do
          Models::MessageTotal.create!(status: "published", partition: 1, value: 20)
          Models::MessageCount.create!(status: "published", partition: 1, value: 10)
        end

        let!(:message) { create(:outboxer_message, :published) }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }

        let!(:result) { Message.delete(id: message.id) }

        it "deletes the message" do
          expect(Models::Message).not_to exist(message.id)
        end

        it "decrements the count failed metric" do
          expect(Message.count_by_status["published"]).to eq(9)
        end

        it "increments the total failed metric" do
          expect(Message.total_by_status["published"]).to eq(20)
        end

        it "returns the message id" do
          expect(result[:id]).to eq(message.id)
        end
      end
    end
  end
end
