require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.counts_by_status' do
      context 'when no messages exist' do
        it 'returns 0 for all statuses' do
          expect(Messages.counts_by_status).to eq({
            all: { count: 0 },
            queued: { count: 0 },
            dequeued: { count: 0 },
            publishing: { count: 0 },
            failed: { count: 0 }
          })
        end
      end

      context 'when messages exist' do
        before do
          create_list(:outboxer_message, 2, :queued)
          create_list(:outboxer_message, 3, :dequeued)
          create_list(:outboxer_message, 5, :publishing)
          create_list(:outboxer_message, 4, :failed)
        end

        it 'returns correct counts for each status' do
          expect(Messages.counts_by_status).to eq({
            all: { count: 14 },
            queued: { count: 2 },
            dequeued: { count: 3 },
            publishing: { count: 5 },
            failed: { count: 4 } })
        end
      end
    end
  end
end
