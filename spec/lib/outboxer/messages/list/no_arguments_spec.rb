require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.list' do
      let!(:message_1) do
        create(:outboxer_message, :queued,
          messageable_type: 'Event', messageable_id: '1',
          updated_by: 'server-01:41000')
      end

      let!(:message_2) do
        create(:outboxer_message, :failed,
          messageable_type: 'Event', messageable_id: '2',
          updated_by: 'server-02:42000')
      end

      let!(:message_3) do
        create(:outboxer_message, :dequeued,
          messageable_type: 'Event', messageable_id: '3',
          updated_by: 'server-03:43000')
      end

      let!(:message_4) do
        create(:outboxer_message, :queued,
          messageable_type: 'Event', messageable_id: '4',
          updated_by: 'server-04:44000')
      end

      let!(:message_5) do
        create(:outboxer_message, :publishing,
          messageable_type: 'Event', messageable_id: '5',
          updated_by: 'server-05:45000')
      end

      context 'when no arguments specified' do
        it 'returns all messages' do
          expect(Messages.list).to eq({
            current_page: 1, limit_value: 100, total_count: 5, total_pages: 1,
            messages: [
              {
                id: message_1.id,
                status: message_1.status.to_sym,
                messageable_type: message_1.messageable_type,
                messageable_id: message_1.messageable_id,
                created_at: message_1.created_at,
                updated_at: message_1.updated_at,
                updated_by: message_1.updated_by
              },
              {
                id: message_2.id,
                status: message_2.status.to_sym,
                messageable_type: message_2.messageable_type,
                messageable_id: message_2.messageable_id,
                created_at: message_2.created_at,
                updated_at: message_2.updated_at,
                updated_by: message_2.updated_by
              },
              {
                id: message_3.id,
                status: message_3.status.to_sym,
                messageable_type: message_3.messageable_type,
                messageable_id: message_3.messageable_id,
                created_at: message_3.created_at,
                updated_at: message_3.updated_at,
                updated_by: message_3.updated_by
              },
              {
                id: message_4.id,
                status: message_4.status.to_sym,
                messageable_type: message_4.messageable_type,
                messageable_id: message_4.messageable_id,
                created_at: message_4.created_at,
                updated_at: message_4.updated_at,
                updated_by: message_4.updated_by
              },
              {
                id: message_5.id,
                status: message_5.status.to_sym,
                messageable_type: message_5.messageable_type,
                messageable_id: message_5.messageable_id,
                created_at: message_5.created_at,
                updated_at: message_5.updated_at,
                updated_by: message_5.updated_by
              }
            ]
          })
        end
      end
    end
  end
end
