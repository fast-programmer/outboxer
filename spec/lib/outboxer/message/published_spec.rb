require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.published' do
      context 'when publishing message' do
        let!(:publishing_message) { create(:outboxer_message, :publishing) }

        let!(:published_message) { Message.published(id: publishing_message.id) }

        it 'returns nil' do
          expect(published_message).to eq({ 'id' => publishing_message.id })
        end

        it 'deletes publishing message' do
          expect(Models::Message.count).to eq(0)
        end
      end

      context 'when backlogged messaged' do
        let(:backlogged_message) { create(:outboxer_message, :backlogged) }

        it 'raises invalid transition error' do
          expect do
            Message.published(id: backlogged_message.id)
          end.to raise_error(
            Message::InvalidTransition,
            "cannot transition outboxer message #{backlogged_message.id} " +
              "from backlogged to (deleted)")
        end

        it 'does not delete backlogged message' do
          begin
            Message.published(id: backlogged_message.id)
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
