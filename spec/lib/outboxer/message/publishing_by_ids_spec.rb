require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".publishing_by_ids" do
      context "when messages are buffered" do
        let!(:messages) do
          [
            create(:outboxer_message, :buffered),
            create(:outboxer_message, :buffered)
          ]
        end

        let(:ids) { messages.map(&:id) }

        it "transitions buffered messages to publishing and returns serialized results" do
          result = Message.publishing_by_ids(ids: ids)

          expect(result.count).to eq(2)
          expect(result.map { |message| message[:id] }).to match_array(ids)

          expect(Models::Message.publishing.pluck(:id)).to match_array(ids)
        end
      end

      context "when a message is queued" do
        let!(:messages) do
          [
            create(:outboxer_message, :buffered),
            create(:outboxer_message, :queued)
          ]
        end

        let(:ids) { messages.map(&:id) }

        it "does not update any messages" do
          begin
            Message.publishing_by_ids(ids: ids)
          rescue ArgumentError
            # no op
          end

          expect(Models::Message.group(:status).count).to eq({ "buffered" => 1, "queued" => 1 })
        end

        it "raises error" do
          expect do
            Message.publishing_by_ids(ids: ids)
          end.to raise_error(ArgumentError, /not buffered/)
        end
      end
    end
  end
end
