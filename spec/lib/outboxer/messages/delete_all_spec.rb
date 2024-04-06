require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.delete_all' do
      let!(:message_1) { create(:outboxer_message, :failed) }
      let!(:exception_1) { create(:outboxer_exception, message: message_1) }
      let!(:frame_1) { create(:outboxer_frame, exception: exception_1) }

      let!(:message_2) { create(:outboxer_message, :failed) }
      let!(:exception_2) { create(:outboxer_exception, message: message_2) }
      let!(:frame) { create(:outboxer_frame, exception: exception_2) }

      let!(:result) { Messages.delete_all }

      it 'deletes all messages' do
        expect(Models::Message.count).to eq(0)
      end

      it 'deletes all exceptions' do
        expect(Models::Exception.count).to eq(0)
      end

      it 'deletes all frames' do
        expect(Models::Frame.count).to eq(0)
      end

      it 'returns count' do
        expect(result[:count]).to eq(2)
      end
    end
  end
end
