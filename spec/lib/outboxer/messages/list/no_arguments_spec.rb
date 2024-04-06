require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.list' do
      let!(:messages) do
        [
          create(:outboxer_message, :backlogged,
            id: 1, messageable_type: 'Event', messageable_id: 1),
          create(:outboxer_message, :failed,
            id: 2, messageable_type: 'Event', messageable_id: 2),
          create(:outboxer_message, :queued,
            id: 3, messageable_type: 'Event', messageable_id: 3),
          create(:outboxer_message, :backlogged,
            id: 4, messageable_type: 'Event', messageable_id: 4)
        ]
      end

      it 'returns all messages ordered by last updated at asc' do
        expect(
          Messages.list.map do |message|
            message.slice(:id, :status, :messageable_type, :messageable_id)
          end
        ).to match_array([
          { id: 1, status: 'backlogged', messageable_type: 'Event', messageable_id: '1' },
          { id: 2, status: 'failed', messageable_type: 'Event', messageable_id: '2' },
          { id: 3, status: 'queued', messageable_type: 'Event', messageable_id: '3' },
          { id: 4, status: 'backlogged', messageable_type: 'Event', messageable_id: '4' },
        ])
      end
    end
  end
end
