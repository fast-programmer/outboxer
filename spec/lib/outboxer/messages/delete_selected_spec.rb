require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.delete_selected' do
      let!(:message_1) { create(:outboxer_message, :queued) }

      let!(:message_2) { create(:outboxer_message, :dequeued) }

      let!(:message_3) { create(:outboxer_message, :failed) }
      let!(:exception_3) { create(:outboxer_exception, message: message_3) }
      let!(:frame_3) { create(:outboxer_frame, exception: exception_3) }

      let!(:message_4) { create(:outboxer_message, :queued) }

      describe 'when ids exist' do
        let!(:ids) { [message_1.id, message_2.id, message_3.id] }
        let!(:result) { Messages.delete_selected(ids: ids) }

        it 'deletes selected messages' do
          expect(Models::Frame.count).to eq(0)
          expect(Models::Exception.count).to eq(0)
          expect(Models::Message.order(id: :asc).pluck(:id)).to eq([message_4.id])
        end

        it 'returns correct result' do
          expect(result).to eq({ deleted_count: ids.count, not_deleted_ids: [] })
        end
      end

      describe 'when an id does not exist' do
        let(:non_existent_id) { 5 }
        let(:result) { Messages.delete_selected(ids: [message_1.id, non_existent_id]) }

        it 'does not delete selected messages' do
          expect(Models::Frame.count).to eq(1)
          expect(Models::Exception.count).to eq(1)
          expect(Models::Message.count).to eq(4)
        end

        it 'returns correct result' do
          expect(result).to eq({ deleted_count: 1, not_deleted_ids: [non_existent_id]  })
        end
      end
    end
  end
end
