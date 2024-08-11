require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.delete_by_ids' do
      let!(:metric) { Models::Metric.find_by!(name: 'messages.published.count.historic') }
      before { metric.update!(value: BigDecimal('20')) }

      let!(:message_1) { create(:outboxer_message, :queued) }
      let!(:exception_1) { create(:outboxer_exception, message: message_1) }
      let!(:frame_1) { create(:outboxer_frame, exception: exception_1) }

      let!(:message_2) { create(:outboxer_message, :dequeued) }
      let!(:exception_2) { create(:outboxer_exception, message: message_2) }
      let!(:frame_2) { create(:outboxer_frame, exception: exception_2) }

      let!(:message_3) { create(:outboxer_message, :publishing) }
      let!(:exception_3) { create(:outboxer_exception, message: message_3) }
      let!(:frame_3) { create(:outboxer_frame, exception: exception_3) }

      let!(:message_4) { create(:outboxer_message, :published) }
      let!(:exception_4) { create(:outboxer_exception, message: message_4) }
      let!(:frame_4) { create(:outboxer_frame, exception: exception_4) }

      let!(:message_5) { create(:outboxer_message, :failed) }
      let!(:exception_5) { create(:outboxer_exception, message: message_5) }
      let!(:frame_5) { create(:outboxer_frame, exception: exception_5) }

      let!(:message_6) { create(:outboxer_message, :published) }
      let!(:exception_6) { create(:outboxer_exception, message: message_6) }
      let!(:frame_6) { create(:outboxer_frame, exception: exception_6) }


      describe 'when ids exist' do
        let!(:ids) { [message_1.id, message_2.id, message_3.id, message_4.id, message_5.id] }

        let!(:result) { Messages.delete_by_ids(ids: ids) }

        it 'deletes selected messages' do
          expect(Models::Message.order(id: :asc).pluck(:id)).to eq([message_6.id])
          expect(Models::Exception.order(id: :asc).pluck(:id)).to eq([exception_6.id])
          expect(Models::Frame.order(id: :asc).pluck(:id)).to eq([frame_6.id])
        end

        it 'adds published messages count to metrics value' do
          metric.reload

          expect(metric.value).to eq(21)
        end

        it 'returns correct result' do
          expect(result).to eq({ deleted_count: ids.count, not_deleted_ids: [] })
        end
      end

      describe 'when an id does not exist' do
        let!(:non_existent_id) { 7 }
        let!(:result) { Messages.delete_by_ids(ids: [message_1.id, non_existent_id]) }

        it 'does not delete selected messages' do
          expect(Models::Frame.count).to eq(5)
          expect(Models::Exception.count).to eq(5)
          expect(Models::Message.count).to eq(5)
        end

        it 'does not add published messages count to metrics value' do
          metric.reload

          expect(metric.value).to eq(20)
        end

        it 'returns correct result' do
          expect(result).to eq({ deleted_count: 1, not_deleted_ids: [non_existent_id]  })
        end
      end
    end
  end
end
