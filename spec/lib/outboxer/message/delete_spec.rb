require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.delete!' do
      context 'when the message status is failed' do
        let!(:message) { create(:outboxer_message, :failed) }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }

        let!(:result) { Message.delete(id: message.id) }

        it 'deletes the message' do
          expect(Models::Message).not_to exist(message.id)
        end

        it 'returns the message id' do
          expect(result[:id]).to eq(message.id)
        end
      end

      context 'when the message status is published' do
        let!(:setting) { Models::Setting.find_by!(name: 'messages.published.count.historic') }
        before { setting.update!(value: '10') }

        let!(:message) { create(:outboxer_message, status: 'published') }
        let!(:exception) { create(:outboxer_exception, message: message) }
        let!(:frame) { create(:outboxer_frame, exception: exception) }

        let!(:result) { Message.delete(id: message.id) }

        it 'increments the published.count.historic metric' do
          setting.reload

          expect(setting.value).to eq('11')
        end

        it 'deletes the message' do
          expect(Models::Message).not_to exist(message.id)
        end

        it 'returns the message id' do
          expect(result[:id]).to eq(message.id)
        end
      end
    end
  end
end
