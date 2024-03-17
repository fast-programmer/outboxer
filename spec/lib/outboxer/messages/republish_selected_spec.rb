require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.republish_selected!' do
      let!(:message_1) { create(:outboxer_message, :failed) }
      let!(:exception_1) { create(:outboxer_exception, message: message_1) }
      let!(:frame_1) { create(:outboxer_frame, exception: exception_1) }

      let!(:message_2) { create(:outboxer_message, :failed) }
      let!(:exception_2) { create(:outboxer_exception, message: message_2) }
      let!(:frame) { create(:outboxer_frame, exception: exception_2) }

      let!(:ids) { [message_1.id, message_2.id] }
      let!(:result) { Messages.republish_selected!(ids: ids) }

      it 'sets message status to unpublished' do
        expect(
          Models::Message
            .where(status: Models::Message::Status::UNPUBLISHED)
            .order(id: :asc)
            .pluck(:id)
        ).to eq(ids)
      end

      it 'sets message status to unpublished' do
        expect(
          Models::Message
            .where(status: Models::Message::Status::UNPUBLISHED)
            .order(id: :asc)
            .pluck(:id)
        ).to eq(ids)
      end

      it 'returns ids' do
        expect(result['count']).to eq(ids.count)
      end
    end
  end
end
