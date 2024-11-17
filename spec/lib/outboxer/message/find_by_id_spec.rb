require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.find_by_id' do
      context 'when a failed message exists' do
        let!(:message) do
          create(:outboxer_message, :failed,
            updated_by_publisher_id: 666,
            updated_by_publisher_name: 'server-01:47000')
        end
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }

        it 'returns the message, exceptions and frames' do
          result = Message.find_by_id(id: message.id)

          expect(result[:id]).to eq(message.id)
          expect(result[:status]).to eq('failed')
          expect(result[:queued_at]).to eq(message.queued_at.utc)
          expect(result[:updated_at]).to eq(message.updated_at.utc)
          expect(result[:updated_by_publisher_id]).to eq(message.updated_by_publisher_id)
          expect(result[:updated_by_publisher_name]).to eq(message.updated_by_publisher_name)
          expect(result[:exceptions].first[:id]).to eq(exception.id)
          expect(result[:exceptions].first[:class_name]).to eq(exception.class_name)
          expect(result[:exceptions].first[:message_text]).to eq(exception.message_text)
          expect(result[:exceptions].first[:frames].first[:id]).to eq(frame.id)
          expect(result[:exceptions].first[:frames].first[:index]).to eq(frame.index)
          expect(result[:exceptions].first[:frames].first[:text]).to eq(frame.text)
        end
      end

      context 'when the message does not exist' do
        it 'raises an ActiveRecord::RecordNotFound error' do
          expect { Message.find_by_id(id: -1) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
