require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.counts_by_status' do
      context 'when no messages exist' do
        it 'returns 0 for all statuses' do
          expect(Messages.counts_by_status).to eq({
            all: 0,
            backlogged: 0,
            queued: 0,
            publishing: 0,
            failed: 0
          })
        end
      end

      context 'when messages exist' do
        before do
          create_list(:outboxer_message, 2, :backlogged)
          create_list(:outboxer_message, 3, :queued)
          create_list(:outboxer_message, 5, :publishing)
          create_list(:outboxer_message, 4, :failed)
        end

        it 'returns correct counts for each status' do
          expect(Messages.counts_by_status).to eq({
            all: 14,
            backlogged: 2,
            queued: 3,
            publishing: 5,
            failed: 4 })
        end
      end
    end
  end
end
