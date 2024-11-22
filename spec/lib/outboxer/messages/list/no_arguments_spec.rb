require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.list' do
      let!(:message_1) do
        create(:outboxer_message, :queued,
          messageable_type: 'Event', messageable_id: '1',
          updated_at: 5.minutes.ago,
          updated_by_publisher_id: 41000,
          updated_by_publisher_name: 'server-01:41000')
      end

      let!(:message_2) do
        create(:outboxer_message, :failed,
          messageable_type: 'Event', messageable_id: '2',
          updated_at: 4.minutes.ago,
          updated_by_publisher_id: 42000,
          updated_by_publisher_name: 'server-02:42000')
      end

      let!(:message_3) do
        create(:outboxer_message, :buffered,
          messageable_type: 'Event', messageable_id: '3',
          updated_at: 3.minutes.ago,
          updated_by_publisher_id: 43000,
          updated_by_publisher_name: 'server-03:43000')
      end

      let!(:message_4) do
        create(:outboxer_message, :queued,
          messageable_type: 'Event', messageable_id: '4',
          updated_at: 2.minutes.ago,
          updated_by_publisher_id: 44000,
          updated_by_publisher_name: 'server-04:44000')
      end

      let!(:message_5) do
        create(:outboxer_message, :publishing,
          messageable_type: 'Event', messageable_id: '5',
          updated_at: 1.minutes.ago,
          updated_by_publisher_id: 45000,
          updated_by_publisher_name: 'server-05:45000')
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
                queued_at: message_1.queued_at,
                buffered_at: message_1.buffered_at,
                publishing_at: message_1.publishing_at,
                updated_at: message_1.updated_at,
                updated_by_publisher_id: message_1.updated_by_publisher_id,
                updated_by_publisher_name: message_1.updated_by_publisher_name
              },
              {
                id: message_2.id,
                status: message_2.status.to_sym,
                messageable_type: message_2.messageable_type,
                messageable_id: message_2.messageable_id,
                queued_at: message_2.queued_at,
                buffered_at: message_2.buffered_at,
                publishing_at: message_2.publishing_at,
                updated_at: message_2.updated_at,
                updated_by_publisher_id: message_2.updated_by_publisher_id,
                updated_by_publisher_name: message_2.updated_by_publisher_name
              },
              {
                id: message_3.id,
                status: message_3.status.to_sym,
                messageable_type: message_3.messageable_type,
                messageable_id: message_3.messageable_id,
                queued_at: message_3.queued_at,
                buffered_at: message_3.buffered_at,
                publishing_at: message_3.publishing_at,
                updated_at: message_3.updated_at,
                updated_by_publisher_id: message_3.updated_by_publisher_id,
                updated_by_publisher_name: message_3.updated_by_publisher_name
              },
              {
                id: message_4.id,
                status: message_4.status.to_sym,
                messageable_type: message_4.messageable_type,
                messageable_id: message_4.messageable_id,
                queued_at: message_4.queued_at,
                buffered_at: message_4.buffered_at,
                publishing_at: message_4.publishing_at,
                updated_at: message_4.updated_at,
                updated_by_publisher_id: message_4.updated_by_publisher_id,
                updated_by_publisher_name: message_4.updated_by_publisher_name
              },
              {
                id: message_5.id,
                status: message_5.status.to_sym,
                messageable_type: message_5.messageable_type,
                messageable_id: message_5.messageable_id,
                queued_at: message_5.queued_at,
                buffered_at: message_5.buffered_at,
                publishing_at: message_5.publishing_at,
                updated_at: message_5.updated_at,
                updated_by_publisher_id: message_5.updated_by_publisher_id,
                updated_by_publisher_name: message_5.updated_by_publisher_name
              }
            ]
          })
        end
      end
    end
  end
end
