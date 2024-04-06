require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.publishing' do
      context 'when queued message' do
        let!(:queued_message) { create(:outboxer_message, :queued) }
        let!(:publishing_message) { Message.publishing(id: queued_message.id) }

        it 'returns publishing message' do
          expect(publishing_message[:id]).to eq(Models::Message.publishing.last.id)
        end
      end

      context 'when backlogged messaged' do
        let!(:backlogged_message) { create(:outboxer_message, :backlogged) }

        it 'raises invalid transition error' do
          expect do
            Message.publishing(id: backlogged_message.id)
          end.to raise_error(
            Message::InvalidTransition,
            "cannot transition outboxer message #{backlogged_message.id} " +
              "from backlogged to publishing")
        end

        it 'does not delete backlogged message' do
          begin
            Message.publishing(id: backlogged_message.id)
          rescue Message::InvalidTransition
            # ignore
          end

          expect(Models::Message.count).to eq(1)
          expect(Models::Message.first).to eq(backlogged_message)
        end
      end
    end
  end
end
