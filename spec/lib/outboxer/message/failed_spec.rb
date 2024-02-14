require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.failed!' do
      let(:exception) do
        def raise_exception
          begin
            raise StandardError.new('unhandled error')
          rescue StandardError => e
            e
          end
        end

        raise_exception
      end

      context 'when publishing message' do
        let!(:publishing_message) do
          Models::Message.create!(
            messageable_type: 'DummyType',
            messageable_id: 1,
            status: Models::Message::Status::PUBLISHING,
            created_at: DateTime.parse('2024-01-14T00:00:00Z'))
        end

        let!(:failed_message) { Message.failed!(id: publishing_message.id, exception: exception) }

        it 'returns updated message' do
          expect(failed_message.id).to eq(publishing_message.id)
          expect(failed_message.status).to eq(Models::Message::Status::FAILED)
        end

        it 'updates message status to failed' do
          publishing_message.reload

          expect(publishing_message.status).to eq(Models::Message::Status::FAILED)
        end

        it 'creates exception' do
          publishing_message.reload

          expect(publishing_message.exceptions.length).to eq(1)
          expect(publishing_message.exceptions[0].class_name).to eq(exception.class.name)
          expect(publishing_message.exceptions[0].message_text).to eq(exception.message)
        end

        it 'creates frames' do
          publishing_message.reload

          expect(publishing_message.exceptions[0].frames.length).to eq(65)

          expect(publishing_message.exceptions[0].frames[0].index).to eq(0)
          expect(publishing_message.exceptions[0].frames[0].text)
            .to include('outboxer/spec/lib/outboxer/message/failed_spec.rb:9:in `raise_exception')
        end
      end

      context 'when unpublished messaged' do
        let(:unpublished_message) do
          Models::Message.create!(
            messageable_type: 'DummyType',
            messageable_id: 1,
            status: Models::Message::Status::UNPUBLISHED,
            created_at: DateTime.parse('2024-01-14T00:00:00Z'))
        end

        it 'raises invalid transition error' do
          expect do
            Message.failed!(id: unpublished_message.id, exception: exception)
          end.to raise_error(
            Message::InvalidTransition,
            "cannot transition outboxer message #{unpublished_message.id} " +
              "from unpublished to failed")
        end

        it 'does not delete unpublished message' do
          begin
            Message.failed!(id: unpublished_message.id, exception: exception)
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
