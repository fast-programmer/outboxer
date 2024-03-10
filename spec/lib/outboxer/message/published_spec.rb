require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.published!' do
      context 'when publishing message' do
        let!(:publishing_message) { create(:outboxer_message, :publishing) }

        let!(:published_message) { Message.published!(id: publishing_message.id) }

        it 'returns nil' do
          expect(published_message).to be_nil
        end

        it 'deletes publishing message' do
          expect(Models::Message.count).to eq(0)
        end
      end

      context 'when unpublished messaged' do
        let(:unpublished_message) { create(:outboxer_message, :unpublished) }

        it 'raises invalid transition error' do
          expect do
            Message.published!(id: unpublished_message.id)
          end.to raise_error(
            Message::InvalidTransition,
            "cannot transition outboxer message #{unpublished_message.id} " +
              "from unpublished to (deleted)")
        end

        it 'does not delete unpublished message' do
          begin
            Message.published!(id: unpublished_message.id)
          rescue Message::InvalidTransition
            # ignore
          end

          expect(Models::Message.count).to eq(1)
          expect(Models::Message.first).to eq(unpublished_message)
        end
      end
    end
  end
end
