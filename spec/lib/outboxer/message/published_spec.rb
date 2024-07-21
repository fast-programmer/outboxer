require "spec_helper"

module Outboxer
  RSpec.describe Message do
    describe ".published" do
      context "when publishing message" do
        let!(:publishing_message) { create(:outboxer_message, :publishing) }

        let!(:published_message) { Message.published(id: publishing_message.id) }

        it "returns nil" do
          expect(published_message).to eq({ id: publishing_message.id })
        end

        it "deletes publishing message" do
          expect(Models::Message.count).to eq(0)
        end
      end

      context "when queued messaged" do
        let!(:queued_message) { create(:outboxer_message, :queued) }

        it "raises invalid transition error" do
          expect do
            Message.published(id: queued_message.id)
          end.to raise_error(
            ArgumentError,
            "cannot transition outboxer message #{queued_message.id} " \
            "from queued to (deleted)")
        end

        it "does not delete queued message" do
          begin
            Message.published(id: queued_message.id)
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
