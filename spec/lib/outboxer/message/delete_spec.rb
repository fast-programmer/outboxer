require "spec_helper"

module Outboxer
  RSpec.describe Message do
    describe ".delete!" do
      context "when the message status is failed" do
        let!(:failed_count_historic_setting) do
          Models::Setting.find_by!(name: "messages.failed.count.historic")
        end

        before { failed_count_historic_setting.update!(value: "20") }

        let!(:message) { create(:outboxer_message, :failed) }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }

        let!(:result) { Message.delete(id: message.id) }

        it "increments the failed.count.historic metric" do
          failed_count_historic_setting.reload

          expect(failed_count_historic_setting.value).to eq("21")
        end

        it "deletes the message" do
          expect(Models::Message).not_to exist(message.id)
        end

        it "returns the message id" do
          expect(result[:id]).to eq(message.id)
        end
      end

      context "when the message status is published" do
        let!(:published_count_historic_setting) do
          Models::Setting.find_by!(name: "messages.published.count.historic")
        end

        before { published_count_historic_setting.update!(value: "10") }

        let!(:message) { create(:outboxer_message, status: "published") }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }

        let!(:result) { Message.delete(id: message.id) }

        it "increments the published.count.historic metric" do
          published_count_historic_setting.reload

          expect(published_count_historic_setting.value).to eq("11")
        end

        it "deletes the message" do
          expect(Models::Message).not_to exist(message.id)
        end

        it "returns the message id" do
          expect(result[:id]).to eq(message.id)
        end
      end
    end
  end
end
