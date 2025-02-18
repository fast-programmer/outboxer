require "rails_helper"

module Outboxer
  RSpec.describe MessageService do
    describe ".publishing" do
      context "when buffered message" do
        let!(:buffered_message) { create(:outboxer_message, :buffered) }
        let!(:publishing_message) { MessageService.publishing(id: buffered_message.id) }

        it "returns publishing message" do
          expect(publishing_message[:id]).to eq(Message.publishing.last.id)
        end
      end

      context "when queued messaged" do
        let!(:queued_message) { create(:outboxer_message, :queued) }

        it "raises invalid transition error" do
          expect do
            MessageService.publishing(id: queued_message.id)
          end.to raise_error(
            ArgumentError,
            "cannot transition outboxer message #{queued_message.id} from queued to publishing")
        end

        it "does not delete queued message" do
          begin
            MessageService.publishing(id: queued_message.id)
          rescue ArgumentError
            # ignore
          end

          expect(Message.count).to eq(1)
          expect(Message.first).to eq(queued_message)
        end
      end
    end
  end
end
