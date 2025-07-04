require "rails_helper"

module Outboxer
  RSpec.describe Publisher do
    let(:id) { 1 }
    let(:name) { "test" }

    describe ".messages_publishing_by_ids" do
      context "when messages are buffered" do
        let!(:messages) do
          [
            create(:outboxer_message, :buffered),
            create(:outboxer_message, :buffered)
          ]
        end

        let(:message_ids) { messages.map(&:id) }

        it "transitions buffered messages to publishing and returns serialized results" do
          result = Publisher.messages_publishing_by_ids(
            id: id, name: name, message_ids: message_ids)

          expect(result.count).to eq(2)
          expect(result.map { |message| message[:id] }).to match_array(message_ids)

          expect(Models::Message.publishing.pluck(:id)).to match_array(message_ids)
        end
      end

      context "when a message is queued" do
        let!(:messages) do
          [
            create(:outboxer_message, :buffered),
            create(:outboxer_message, :queued)
          ]
        end

        let(:message_ids) { messages.map(&:id) }

        it "does not update any messages" do
          begin
            Publisher.messages_publishing_by_ids(id: id, name: name, message_ids: message_ids)
          rescue ArgumentError
            # no op
          end

          expect(Models::Message.group(:status).count).to eq({ "buffered" => 1, "queued" => 1 })
        end

        it "raises error" do
          expect do
            Publisher.messages_publishing_by_ids(id: id, name: name, message_ids: message_ids)
          end.to raise_error(ArgumentError, /not buffered/)
        end
      end
    end
  end
end
