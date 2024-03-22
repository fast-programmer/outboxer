require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.delete!' do
      let!(:message) { create(:outboxer_message, :failed) }
      let!(:exception) { create(:outboxer_exception, message: message) }
      let!(:frame) { create(:outboxer_frame, exception: exception) }

      let!(:result) { Message.delete!(id: message.id) }

      it 'deletes the message' do
        expect(Models::Message).not_to exist(message.id)
      end

      it 'returns the message id' do
        expect(result['id']).to eq(message.id)
      end
    end
  end
end
