require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".published_by_ids" do
      context "when messages are publishing" do
        let!(:messages) do
          [
            create(:outboxer_message, :publishing),
            create(:outboxer_message, :publishing)
          ]
        end

        let(:ids) { messages.map(&:id) }

        it "transitions publishing messages to published and returns serialized results" do
          result = Message.published_by_ids(ids: ids)

          expect(result.count).to eq(2)
          expect(result.map { |message| message[:id] }).to match_array(ids)

          expect(Models::Message.published.pluck(:id)).to match_array(ids)
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
            Message.published_by_ids(ids: ids)
          rescue ArgumentError
            # no op
          end

          expect(Models::Message.group(:status).count).to eq({ "buffered" => 1, "queued" => 1 })
        end

        it "raises error if any message is not buffered" do
          expect do
            Message.published_by_ids(ids: ids)
          end.to raise_error(ArgumentError, /not publishing/)
        end
      end
    end
  end
end
