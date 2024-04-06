require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.republish_selected' do
      let!(:message_1) { create(:outboxer_message, :failed) }
      let!(:exception_1) { create(:outboxer_exception, message: message_1) }
      let!(:frame_1) { create(:outboxer_frame, exception: exception_1) }

      let!(:message_2) { create(:outboxer_message, :failed) }
      let!(:exception_2) { create(:outboxer_exception, message: message_2) }
      let!(:frame_2) { create(:outboxer_frame, exception: exception_2) }

      let!(:ids) { [message_1.id, message_2.id] }
      let!(:result) { Messages.republish_selected(ids: ids) }

      describe 'when ids exist' do
        it 'sets message status to backlogged' do
          expect(
            Models::Message
              .where(status: Models::Message::Status::BACKLOGGED)
              .order(id: :asc)
              .pluck(:id)
          ).to eq(ids)
        end

        it 'returns count' do
          expect(result['count']).to eq(ids.count)
        end
      end

      describe 'when an id does not exist' do
        let(:nonexistent_id) { 5 }

        it 'raises NotFound' do
          expect { Messages.republish_selected(ids: [nonexistent_id]) }
            .to raise_error(NotFound, "Some IDs could not be found: #{nonexistent_id}")
        end

        it 'does not delete selected messages' do
          expect(Models::Frame.count).to eq(2)
          expect(Models::Exception.count).to eq(2)
          expect(Models::Message.count).to eq(2)
        end
      end
    end
  end
end
