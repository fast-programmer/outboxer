require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.counts_by_status' do
      context 'when no messages exist' do
        it 'returns 0 for all statuses' do
          expected_counts = { 'backlogged' => 0, 'publishing' => 0, 'failed' => 0 }

          expect(Outboxer::Messages.counts_by_status).to eq(expected_counts)
        end
      end

      context 'when messages exist' do
        before do
          create_list(:outboxer_message, 2, :backlogged)
          create_list(:outboxer_message, 3, :publishing)
          create_list(:outboxer_message, 4, :failed)
        end

        it 'returns correct counts for each status' do
          expected_counts = { 'backlogged' => 2, 'publishing' => 3, 'failed' => 4 }

          expect(Messages.counts_by_status).to eq(expected_counts)
        end
      end
    end
  end
end
