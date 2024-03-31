require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.republish_all!' do
      let!(:message_1) { create(:outboxer_message, :backlogged) }
      let!(:exception_1) { create(:outboxer_exception, message: message_1) }
      let!(:frame_1) { create(:outboxer_frame, exception: exception_1) }

      let!(:message_2) { create(:outboxer_message, :publishing) }
      let!(:exception_2) { create(:outboxer_exception, message: message_2) }
      let!(:frame_2) { create(:outboxer_frame, exception: exception_2) }

      let!(:message_3) { create(:outboxer_message, :failed) }
      let!(:exception_3) { create(:outboxer_exception, message: message_3) }
      let!(:frame_3) { create(:outboxer_frame, exception: exception_3) }

      let!(:message_4) { create(:outboxer_message, :failed) }
      let!(:exception_4) { create(:outboxer_exception, message: message_4) }
      let!(:frame_4) { create(:outboxer_frame, exception: exception_4) }

      let!(:result) { Messages.republish_all!(batch_size: 1) }

      it 'sets failed messages to backlogged' do
        expect(
          Models::Message.where(
            id: [message_1, message_3.id, message_4.id],
            status: Models::Message::Status::BACKLOGGED
          ).count
        ).to eq(3)
      end

      it 'does not change messages that are publishing' do
        expect(
          Models::Message.where(id: [message_2], status: Models::Message::Status::PUBLISHING).count
        ).to eq(1)
      end
    end
  end
end
