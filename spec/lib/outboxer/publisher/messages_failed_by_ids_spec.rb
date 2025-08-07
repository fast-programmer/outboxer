require "rails_helper"

module Outboxer
  RSpec.describe Publisher do
    let(:id) { 1 }
    let(:name) { "test" }

    describe ".messages_failed_by_ids" do
      context "when messages are publishing" do
        let!(:messages) do
          [
            create(:outboxer_message, :publishing),
            create(:outboxer_message, :publishing)
          ]
        end

        let(:message_ids) { messages.map(&:id) }

        let(:exception) do
          def raise_exception
            raise StandardError, "something went wrong"
          rescue StandardError => error
            error
          end

          raise_exception
        end

        it "transitions publishing messages to failed and stores exception frames" do
          Publisher.messages_failed_by_ids(
            id: id, name: name, message_ids: message_ids, exception: exception)

          expect(result.count).to eq(2)
          expect(result.map { |message| message[:id] }).to match_array(message_ids)
          expect(Models::Message.failed.pluck(:id)).to match_array(message_ids)
        end
      end

      context "when a message is queued" do
        let!(:messages) do
          [
            create(:outboxer_message, :queued),
            create(:outboxer_message, :publishing)
          ]
        end

        let(:message_ids) { messages.map(&:id) }

        let(:exception) do
          def raise_exception
            raise StandardError, "something went wrong"
          rescue StandardError => error
            error
          end

          raise_exception
        end

        it "does not update any messages" do
          begin
            Publisher.messages_publishing_by_ids(
              id: id, name: name, message_ids: message_ids)
          rescue ArgumentError
            # no op
          end

          expect(Models::Message.group(:status).count).to eq({ "queued" => 1, "publishing" => 1 })
        end

        it "raises error" do
          expect do
            Publisher.messages_failed_by_ids(
              id: id, name: name, message_ids: message_ids, exception: exception)
          end.to raise_error(ArgumentError, /not publishing/)
        end
      end
    end
  end
end
