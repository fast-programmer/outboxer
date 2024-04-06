require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.find_by_id' do
      context 'when a failed message exists' do
        let!(:message) { create(:outboxer_message, :failed) }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }

        it 'returns the message, exceptions and frames' do
          result = Message.find_by_id(id: message.id)

          expect(result[:id]).to eq(message.id)
          expect(result[:status]).to eq('failed')
          expect(result[:created_at]).to eq(message.created_at.utc.to_s)
          expect(result[:updated_at]).to eq(message.updated_at.utc.to_s)
          expect(result[:exceptions].first[:id]).to eq(exception.id)
          expect(result[:exceptions].first[:class_name]).to eq(exception.class_name)
          expect(result[:exceptions].first[:message_text]).to eq(exception.message_text)
          expect(result[:exceptions].first[:frames].first[:id]).to eq(frame.id)
          expect(result[:exceptions].first[:frames].first[:index]).to eq(frame.index)
          expect(result[:exceptions].first[:frames].first[:text]).to eq(frame.text)
        end
      end

      context 'when the message does not exist' do
        it 'raises a NotFound error' do
          expect { Message.find_by_id(id: -1) }.to raise_error(Message::NotFound)
        end
      end
    end
  end
end
