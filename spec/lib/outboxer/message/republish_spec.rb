require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.republish!' do
      context 'when failed message' do
        let!(:failed_message) do
          Models::Message.create!(
            id: SecureRandom.uuid,
            messageable_type: 'DummyType',
            messageable_id: 1,
            status: Models::Message::Status::FAILED,
            created_at: DateTime.parse('2024-01-14T00:00:00Z'))
        end

        let!(:unpublished_message) { Message.republish!(id: failed_message.id) }

        it 'returns unpublished message' do
          expect(unpublished_message.id).to eq(failed_message.id)
          expect(unpublished_message.status).to eq(Models::Message::Status::UNPUBLISHED)
        end

        it 'updates failed message status to unpublishied' do
          failed_message.reload

          expect(failed_message.status).to eq(Models::Message::Status::UNPUBLISHED)
        end
      end

      context 'when unpublished messaged' do
        let(:unpublished_message) do
          Models::Message.create!(
            id: SecureRandom.uuid,
            messageable_type: 'DummyType',
            messageable_id: 1,
            status: Models::Message::Status::UNPUBLISHED,
            created_at: DateTime.parse('2024-01-14T00:00:00Z'))
        end

        it 'raises invalid transition error' do
          expect do
            Message.republish!(id: unpublished_message.id)
          end.to raise_error(
            Message::InvalidTransition,
            "cannot transition outboxer message #{unpublished_message.id} " +
              "from unpublished to unpublished")
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
