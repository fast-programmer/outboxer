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
          create(:outboxer_message, :publishing,
            id: 3, messageable_type: 'Event', messageable_id: 3),
          create(:outboxer_message, :backlogged,
            id: 4, messageable_type: 'Event', messageable_id: 4)
        ]
      end

      it 'returns all messages ordered by last updated at asc' do
        expect(
          Messages.list.map { |message| message.slice('id', 'status', 'messageable') }
        ).to match_array([
          { 'id' => 1, 'status' => 'backlogged', 'messageable' => 'Event::1' },
          { 'id' => 2, 'status' => 'failed', 'messageable' => 'Event::2' },
          { 'id' => 3, 'status' => 'publishing', 'messageable' => 'Event::3' },
          { 'id' => 4, 'status' => 'backlogged', 'messageable' => 'Event::4' },
        ])
      end
    end
  end
end
