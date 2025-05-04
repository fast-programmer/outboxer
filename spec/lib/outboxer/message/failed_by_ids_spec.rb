require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".failed_by_ids" do
      context "when messages are publishing" do
        let!(:messages) do
          [
            create(:outboxer_message, :publishing),
            create(:outboxer_message, :publishing)
          ]
        end

        let(:ids) { messages.map(&:id) }

        let(:exception) do
          def raise_exception
            raise StandardError, "something went wrong"
          rescue StandardError => error
            error
          end

          raise_exception
        end

        it "transitions publishing messages to failed and stores exception frames" do
          result = Message.failed_by_ids(ids: ids, exception: exception)

          expect(result.count).to eq(2)
          expect(result.map { |message| message[:id] }).to match_array(ids)

          expect(Models::Message.failed.pluck(:id)).to match_array(ids)
        end
      end

      context "when a message is queued" do
        let!(:messages) do
          [
            create(:outboxer_message, :queued),
            create(:outboxer_message, :publishing)
          ]
        end

        let(:ids) { messages.map(&:id) }

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
            Message.publishing_by_ids(ids: ids)
          rescue ArgumentError
            # no op
          end

          expect(Models::Message.group(:status).count).to eq({ "queued" => 1, "publishing" => 1 })
        end

        it "raises error" do
          expect do
            Message.failed_by_ids(ids: ids, exception: exception)
          end.to raise_error(ArgumentError, /not publishing/)
        end
      end
    end
  end
end
