require "rails_helper"

module Outboxer
  RSpec.describe MessageService do
    describe ".published" do
      context "when publishing message" do
        let!(:publishing_message) { create(:outboxer_message, :publishing) }

        let!(:published_message) { MessageService.published(id: publishing_message.id) }

        it "returns published message" do
          expect(publishing_message[:id]).to eq(Models::Message.published.last.id)
        end

        it "does not delete published message" do
          expect(Models::Message.count).to eq(1)
        end
      end

      context "when queued messaged" do
        let!(:queued_message) { create(:outboxer_message, :queued) }

        it "raises invalid transition error" do
          expect do
            MessageService.published(id: queued_message.id)
          end.to raise_error(
            ArgumentError,
            "cannot transition outboxer message #{queued_message.id} from queued to published")
        end

        it "does not delete queued message" do
          begin
            MessageService.published(id: queued_message.id)
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
