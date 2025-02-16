require "rails_helper"

module Outboxer
  RSpec.describe MessageService do
    describe ".failed" do
      let(:exception) do
        def raise_exception
          raise StandardError, "unhandled error"
        rescue StandardError => error
          error
        end

        raise_exception
      end

      context "when published message" do
        let!(:publishing_message) { create(:outboxer_message, :publishing) }

        let!(:failed_message) do
          MessageService.failed(id: publishing_message.id, exception: exception)
        end

        it "returns updated message" do
          expect(failed_message[:id]).to eq(publishing_message.id)
        end

        it "updates message status to failed" do
          publishing_message.reload

          expect(publishing_message.status).to eq(Models::Message::Status::FAILED)
        end

        it "creates exception" do
          publishing_message.reload

          expect(publishing_message.exceptions.length).to eq(1)
          expect(publishing_message.exceptions[0].class_name).to eq(exception.class.name)
          expect(publishing_message.exceptions[0].message_text).to eq(exception.message)
        end

        it "creates frames" do
          publishing_message.reload

          expect(publishing_message.exceptions[0].frames.length).to eq(65)

          expect(publishing_message.exceptions[0].frames[0].index).to eq(0)
          expect(publishing_message.exceptions[0].frames[0].text)
            .to include("outboxer/spec/lib/outboxer/services/message_service/" \
              "failed_spec.rb:8:in `raise_exception")
        end
      end

      context "when queued message" do
        let!(:queued_message) { create(:outboxer_message, :queued) }

        it "raises invalid transition error" do
          expect do
            MessageService.failed(id: queued_message.id, exception: exception)
          end.to raise_error(
            ArgumentError,
            "cannot transition outboxer message #{queued_message.id} from queued to failed")
        end

        it "does not delete queued message" do
          begin
            MessageService.failed(id: queued_message.id, exception: exception)
          rescue ArgumentError
            # ignore
          end

          expect(Models::Message.count).to eq(1)
          expect(Models::Message.first).to eq(queued_message)
        end
      end
    end
  end
end
