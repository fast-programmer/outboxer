require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.delete_selected!' do
      let!(:message_1) { create(:outboxer_message, :backlogged) }

      let!(:message_2) { create(:outboxer_message, :publishing) }

      let!(:message_3) { create(:outboxer_message, :failed) }
      let!(:exception_3) { create(:outboxer_exception, message: message_3) }
      let!(:frame_3) { create(:outboxer_frame, exception: exception_3) }

      let!(:message_4) { create(:outboxer_message, :backlogged) }

      describe 'when ids exist' do
        let!(:ids) { [message_1.id, message_2.id, message_3.id] }
        let!(:result) { Messages.delete_selected!(ids: ids) }

        it 'deletes selected messages' do
          expect(Models::Frame.count).to eq(0)
          expect(Models::Exception.count).to eq(0)
          expect(Models::Message.order(id: :asc).pluck(:id)).to eq([message_4.id])
        end

        it 'returns count' do
          expect(result['count']).to eq(ids.count)
        end
      end

      describe 'when an id does not exist' do
        let(:nonexistent_id) { 5 }

        it 'raises NotFound' do
          expect { Messages.delete_selected!(ids: [message_1.id, nonexistent_id]) }
            .to raise_error(NotFound, "Some IDs could not be found: #{nonexistent_id}")
        end

        it 'does not delete selected messages' do
          expect(Models::Frame.count).to eq(1)
          expect(Models::Exception.count).to eq(1)
          expect(Models::Message.count).to eq(4)
        end
      end
    end
  end
end
