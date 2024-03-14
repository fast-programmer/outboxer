require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.list' do
      let!(:messages) do
        [
          create(:outboxer_message, :unpublished,
            id: 1, created_at: 4.minutes.ago, updated_at: 2.minutes.ago),
          create(:outboxer_message, :failed,
            id: 2, created_at: 3.minutes.ago, updated_at: 3.minutes.ago),
          create(:outboxer_message, :publishing,
            id: 3, created_at: 2.minute.ago, updated_at: 2.minutes.ago),
          create(:outboxer_message, :unpublished,
            id: 4, created_at: 1.minute.ago, updated_at: 1.minutes.ago)
        ]
      end

      it 'returns all messages ordered by last updated at desc' do
        expect(Messages.list.map(&:id)).to eq([1, 2, 3, 4])
      end
    end
  end
end
