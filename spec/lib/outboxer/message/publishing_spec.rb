require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.publishing' do
      context 'when buffered message' do
        let!(:buffered_message) { create(:outboxer_message, :buffered) }
        let!(:publishing_message) { Message.publishing(id: buffered_message.id) }

        it 'returns publishing message' do
          expect(publishing_message[:id]).to eq(Models::Message.publishing.last.id)
        end
      end

      context 'when queued messaged' do
        let!(:queued_message) { create(:outboxer_message, :queued) }

        it 'raises invalid transition error' do
          expect do
            Message.publishing(id: queued_message.id)
          end.to raise_error(
            ArgumentError,
            "cannot transition outboxer message #{queued_message.id} " +
              "from queued to publishing")
        end

        it 'does not delete queued message' do
          begin
            Message.publishing(id: queued_message.id)
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
